// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\users\users.service.ts
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { DataSource, Repository } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { User, UserRole } from './entities/user.entity';
import type { SafeUser } from '../auth/types/user.types';

type RawUserRow = { id: string; name: string | null; email: string | null };

@Injectable()
export class UsersService {
  constructor(
    private readonly cfg: ConfigService,
    private readonly dataSource: DataSource,
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
  ) {}

  /** 이메일 정규화 */
  private normEmail(email: string) {
    return (email ?? '').trim().toLowerCase();
  }

  /** 비밀번호 제외 안전 유저 타입 변환 */
  private toSafeUser(u: User): SafeUser {
    const { passwordHash, ...safe } = u as any;
    (safe as any).id = String(u.id);
    return safe as SafeUser;
  }

  /** 회원가입: 일반 유저용 (경쟁조건 안전) */
  async create(dto: { email: string; name: string; password: string }): Promise<SafeUser> {
    const email = this.normEmail(dto.email);

    if (!dto.password || dto.password.length < 4) {
      throw new ConflictException('PASSWORD_TOO_SHORT');
    }

    // 1차 사전 중복 체크
    const exists = await this.usersRepository.findOne({ where: { email } });
    if (exists) throw new ConflictException('EMAIL_IN_USE');

    const rounds = this.cfg.get<number>('BCRYPT_SALT_ROUNDS', 10);
    const passwordHash = await bcrypt.hash(dto.password, rounds);

    const user = this.usersRepository.create({
      email,
      name: (dto.name ?? '').trim().replace(/\s+/g, ' '),
      passwordHash,
      reputation: 0,
      role: UserRole.USER,
      universityName: null,
      universityVerified: false,
    });

    try {
      await this.usersRepository.save(user);
    } catch (e: any) {
      const msg = String(e?.message ?? '').toUpperCase();
      if (
        e?.code === 'ER_DUP_ENTRY' ||
        e?.errno === 1062 ||
        msg.includes('UNIQUE') ||
        msg.includes('SQLITE_CONSTRAINT')
      ) {
        throw new ConflictException('EMAIL_IN_USE');
      }
      throw e;
    }

    // eslint-disable-next-line no-console
    console.log('[UsersService] 🟢 회원가입 완료 (DB):', user.email);
    return this.toSafeUser(user);
  }

  /** 로그인: 해시 포함 원본 조회 (정규화 일관) */
  async findByEmailWithHash(email: string) {
    const e = (email ?? '').trim().toLowerCase();

    // passwordHash가 엔티티에서 select:false 라는 가정 하에 addSelect로 명시 추가
    return this.usersRepository
    .createQueryBuilder('u')
    .where('LOWER(u.email) = :e', { e })
    .andWhere('u.deletedAt IS NULL')
    .addSelect('u.passwordHash')   // ★ 핵심: select:false 컬럼을 명시적으로 포함
    .getOne();
  }

  /** 조회용: 안전 유저 타입 */
  async findByEmail(email: string): Promise<SafeUser | null> {
    const u = await this.findByEmailWithHash(email);
    return u ? this.toSafeUser(u) : null;
  }

  /** ID로 조회(안전 유저 타입) — UUID */
  async findOne(id: string): Promise<SafeUser> {
    const user = await this.usersRepository.findOne({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return this.toSafeUser(user);
  }

  /** (AuthService 호환용) UUID 조회 */
  async findOneByUuid(uuid: string): Promise<SafeUser | null> {
    const user = await this.usersRepository.findOne({ where: { id: uuid } });
    return user ? this.toSafeUser(user) : null;
  }

  /**
   * 통합 사용자 조회 (/api/v1/users/lookup?query=...)
   * - 이메일(@kku.ac.kr) 우선
   * - 이메일 형식이 아니면 보조로 '이름' 완전일치(LOWER) 조회
   */
  async lookupByQuery(
    rawInput: string,
  ): Promise<{ id: string; name?: string; email?: string }> {
    const raw = (rawInput ?? '').trim().toLowerCase();
    if (!raw) throw new NotFoundException('USER_NOT_FOUND');

    const looksEmail = /^[^@\s]+@kku\.ac\.kr$/.test(raw);

    if (looksEmail) {
      // 이메일(대소문자 무시)로 조회
      const byEmail = await this.usersRepository
        .createQueryBuilder('u')
        .select(['u.id AS id', 'u.name AS name', 'u.email AS email'])
        .where('LOWER(u.email) = :raw', { raw })
        .orderBy('u.id', 'ASC')
        .limit(1)
        .getRawOne<RawUserRow>();

      if (byEmail)
        return { id: byEmail.id, name: byEmail.name ?? undefined, email: byEmail.email ?? undefined };
      throw new NotFoundException('USER_NOT_FOUND');
    }

    // 이메일 형식이 아니면: 이름 완전일치(LOWER) 보조 조회
    const byName = await this.usersRepository
      .createQueryBuilder('u')
      .select(['u.id AS id', 'u.name AS name', 'u.email AS email'])
      .where('LOWER(u.name) = :raw', { raw })
      .orderBy('u.id', 'ASC')
      .limit(1)
      .getRawOne<RawUserRow>();

    if (byName)
      return { id: byName.id, name: byName.name ?? undefined, email: byName.email ?? undefined };

    throw new NotFoundException('USER_NOT_FOUND');
  }

  /**
   * 대학교 인증 완료 표시
   * - 이메일 기준으로 유저를 찾아 인증 플래그/학교명 업데이트 (DB만)
   * - 멱등성 보장
   */
  async markUniversityVerifiedByEmail(email: string, universityName: string) {
    const norm = this.normEmail(email);

    const user = await this.usersRepository.findOne({ where: { email: norm } });
    if (!user) {
      return { ok: false as const, reason: 'user_not_found' as const };
    }

    // 멱등성
    if (user.universityVerified && user.universityName === universityName) {
      return { ok: true as const, already: true as const, source: 'db' as const };
    }

    user.universityVerified = true;
    user.universityName = universityName;
    await this.usersRepository.save(user);

    return { ok: true as const, updated: true as const, source: 'db' as const };
  }

  /** 디버그: API가 실제로 붙어있는 DB와 유저 수 확인 */
  async debugDbInfo() {
    try {
      const driver = this.dataSource.options.type;
      let dbname = '(unknown)';
      let userCount = 0;

      if (driver === 'sqlite') {
        dbname = (this.dataSource.options as any).database ?? '(sqlite-memory)';
        const [countRow] = await this.dataSource.query('SELECT COUNT(*) AS count FROM users;');
        userCount = Number(countRow?.count ?? 0);
      } else {
        const [dbRow] = await this.dataSource.query('SELECT DATABASE() AS dbname;');
        dbname = dbRow?.dbname ?? '(unknown)';
        const [countRow] = await this.dataSource.query('SELECT COUNT(*) AS count FROM users;');
        userCount = Number(countRow?.count ?? 0);
      }

      return { database: dbname, userCount };
    } catch (e: any) {
      return { error: e?.message ?? String(e) };
    }
  }

  /** 디버그: users 테이블 이메일 목록(최대 200개) */
  async debugListEmails() {
    try {
      const rows = await this.dataSource.query(
        `SELECT id, email FROM users ORDER BY createdAt DESC LIMIT 200;`,
      );
      return {
        count: rows.length,
        emails: rows.map((r: any) => ({ id: String(r.id), email: String(r.email) })),
      };
    } catch (e: any) {
      return { error: e?.message ?? String(e) };
    }
  }
}
