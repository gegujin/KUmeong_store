// src/modules/users/users.service.ts
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
  /** 테스트용 유저 (메모리 저장) */
  private testUsersByEmail = new Map<string, User>();

  constructor(
    private readonly cfg: ConfigService,
    private readonly dataSource: DataSource,
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
  ) {
    this.initTestUser(); // 동기 등록
  }

  /** 이메일 정규화 */
  private normEmail(email: string) {
    return (email ?? '').trim().toLowerCase();
  }

  /** 비밀번호 제외 안전 유저 타입 변환 */
  private toSafeUser(u: User): SafeUser {
    const { passwordHash, ...safe } = u as any;
    // SafeUser.id는 문자열로 내려가도록 일관화
    (safe as any).id = String(u.id);
    return safe as SafeUser;
  }

  /** 서버 시작 시 테스트용 유저 등록 (즉시 로그인 가능) */
  private initTestUser() {
    const testEmail = this.normEmail('student@kku.ac.kr');
    if (this.testUsersByEmail.has(testEmail)) return;

    const rounds = this.cfg.get<number>('BCRYPT_SALT_ROUNDS', 10);
    const passwordHash = bcrypt.hashSync('password1234', rounds);

    // ✅ UUID PK 스키마에 맞춰 테스트 유저도 UUID로 부여
    const user: User = {
      id: '11111111-1111-1111-1111-111111111111',
      email: testEmail,
      name: 'KKU Student',
      passwordHash,
      reputation: 0,
      role: UserRole.USER,
      universityName: null,
      universityVerified: false,
      createdAt: new Date(),
      updatedAt: new Date(),
      deletedAt: null,
      products: [],
    };

    this.testUsersByEmail.set(testEmail, user);
    // eslint-disable-next-line no-console
    console.log('[UsersService] ✅ 테스트 유저 등록 완료:', user.email);
  }

  /** 회원가입: 일반 유저용 (경쟁조건 안전) */
  async create(dto: { email: string; name: string; password: string }): Promise<SafeUser> {
    const email = this.normEmail(dto.email);

    // 테스트 유저는 회원가입 막기
    if (this.testUsersByEmail.has(email)) {
      throw new ConflictException('EMAIL_IN_USE');
    }

    if (!dto.password || dto.password.length < 4) {
      throw new ConflictException('PASSWORD_TOO_SHORT');
    }

    // 1차 사전 중복 체크
    const exists = await this.usersRepository.findOne({ where: { email } });
    if (exists) throw new ConflictException('EMAIL_IN_USE');

    const rounds = this.cfg.get<number>('BCRYPT_SALT_ROUNDS', 10);
    const passwordHash = await bcrypt.hash(dto.password, rounds);

    const user = this.usersRepository.create({
      // id: DB에서 UUID 생성(트리거나 애플리케이션에서 생성 시 여기에 주입해도 OK)
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
      // ✅ DB UNIQUE 제약으로 최종 판정
      const msg = String(e?.message ?? '').toUpperCase();
      if (e?.code === 'ER_DUP_ENTRY' || e?.errno === 1062 || msg.includes('UNIQUE') || msg.includes('SQLITE_CONSTRAINT')) {
        throw new ConflictException('EMAIL_IN_USE');
      }
      throw e;
    }

    // eslint-disable-next-line no-console
    console.log('[UsersService] 🟢 회원가입 완료 (DB):', user.email);
    return this.toSafeUser(user);
  }

  /** 로그인: 해시 포함 원본 조회 (정규화 일관) */
  async findByEmailWithHash(email: string): Promise<User | null> {
    const norm = this.normEmail(email);

    // 1) 테스트 유저 먼저
    const testUser = this.testUsersByEmail.get(norm);
    if (testUser) {
      // eslint-disable-next-line no-console
      console.log('[UsersService] ✨ 메모리에서 테스트 유저 조회:', testUser.email);
      return testUser;
    }

    // 2) 실제 DB 조회 (passwordHash는 select:false → addSelect)
    const user = await this.usersRepository
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('LOWER(user.email) = :email', { email: norm })
      .andWhere('user.deletedAt IS NULL')
      .getOne();

    // eslint-disable-next-line no-console
    console.log('[UsersService] 🔍 DB에서 조회:', user ? user.email : null);
    return user ?? null;
  }

  /** 조회용: 안전 유저 타입 */
  async findByEmail(email: string): Promise<SafeUser | null> {
    const u = await this.findByEmailWithHash(email);
    return u ? this.toSafeUser(u) : null;
  }

  /** ID로 조회(안전 유저 타입) — UUID */
  async findOne(id: string): Promise<SafeUser> {
    // 테스트 유저 폴백
    if (id === '11111111-1111-1111-1111-111111111111') {
      const test = this.testUsersByEmail.get(this.normEmail('student@kku.ac.kr'));
      if (test) return this.toSafeUser(test);
    }

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
   * ✅ 통합 사용자 조회 (프런트: /api/v1/users/lookup?query=...)
   * - 이메일(@kku.ac.kr) 우선
   * - 이메일 형식이 아니면 보조로 '이름' 완전일치(LOWER) 조회
   * - 반환: { id: string, name?, email? }
   */
  async lookupByQuery(
    rawInput: string,
  ): Promise<{ id: string; name?: string; email?: string }> {
    const raw = (rawInput ?? '').trim().toLowerCase();
    if (!raw) throw new NotFoundException('USER_NOT_FOUND');

    const looksEmail = /^[^@\s]+@kku\.ac\.kr$/.test(raw);

    // 0) 메모리 테스트 유저도 커버
    if (looksEmail) {
      const mem = this.testUsersByEmail.get(raw);
      if (mem) return { id: mem.id, name: mem.name, email: mem.email };
    }

    if (looksEmail) {
      // 1) 이메일(대소문자 무시)로 조회
      const byEmail = await this.usersRepository
        .createQueryBuilder('u')
        .select(['u.id AS id', 'u.name AS name', 'u.email AS email'])
        .where('LOWER(u.email) = :raw', { raw })
        .andWhere('u.deletedAt IS NULL')
        .getRawOne<RawUserRow>();

      if (byEmail) return { id: byEmail.id, name: byEmail.name ?? undefined, email: byEmail.email ?? undefined };
      throw new NotFoundException('USER_NOT_FOUND');
    }

    // 2) 이메일 형식이 아니면: 이름 완전일치(LOWER) 보조 조회
    const byName = await this.usersRepository
      .createQueryBuilder('u')
      .select(['u.id AS id', 'u.name AS name', 'u.email AS email'])
      .where('LOWER(u.name) = :raw', { raw })
      .andWhere('u.deletedAt IS NULL')
      .orderBy('u.id', 'ASC')
      .limit(1)
      .getRawOne<RawUserRow>();

    if (byName) return { id: byName.id, name: byName.name ?? undefined, email: byName.email ?? undefined };

    throw new NotFoundException('USER_NOT_FOUND');
  }

  /**
   * 대학교 인증 완료 표시
   * - 이메일 기준으로 유저를 찾아 인증 플래그/학교명 업데이트
   * - 테스트 유저/DB 유저 모두 처리, 멱등성 보장
   */
  async markUniversityVerifiedByEmail(email: string, universityName: string) {
    const norm = this.normEmail(email);

    // 1) 메모리 테스트 유저
    const t = this.testUsersByEmail.get(norm);
    if (t) {
      t.universityVerified = true;
      t.universityName = universityName;
      t.updatedAt = new Date();
      this.testUsersByEmail.set(norm, t);
      return { ok: true as const, updated: true as const, source: 'memory' as const };
    }

    // 2) 실제 DB 유저
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

  /** ✅ 디버그: API가 실제로 붙어있는 DB와 유저 수 확인 */
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

  /** ✅ 디버그: users 테이블 이메일 목록(최대 200개) */
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
