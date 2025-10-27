// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\users\users.service.ts
// ================================================================
// UsersService — 구조화 버전 (PART A~G)
//  - PART A: imports & types
//  - PART B: class & ctor
//  - PART C: private helpers (정규화/변환)
//  - PART D: 생성/가입
//  - PART E: 조회 (로그인 전용/일반 안전타입/UUID/lookup)
//  - PART F: 대학 인증 플래그 갱신 (멱등)
//  - PART G: 디버그 유틸
// ================================================================

/* PART A. Imports & Types -------------------------------------*/
import {
  ConflictException,
  Injectable,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { DataSource, IsNull, Repository } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { User, UserRole } from './entities/user.entity';

// 프로젝트에 이미 정의돼 있으면 사용하세요.
// 경로가 다르면 맞춰 주세요.
import type { SafeUser } from '../../modules/auth/types/user.types';


type RawUserRow = { id: string; name: string | null; email: string | null };

/* PART B. Class & Constructor ---------------------------------*/
@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);
  constructor(
    private readonly cfg: ConfigService,
    private readonly dataSource: DataSource,
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
  ) {}

  async findByIdOrFail(id: string, fields?: (keyof User)[]) {
    const qb = this.usersRepository
      .createQueryBuilder('u')
      .where('u.id = :id', { id })
      .andWhere('u.deletedAt IS NULL');

    if (fields?.length) {
      qb.select(fields.map((f) => `u.${String(f)}`));
    }

    const user = await qb.getOne();
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  /* PART C. Private Helpers -----------------------------------*/

  /** 이메일 정규화(공백 제거 + 소문자) */
  private normEmail(email: string) {
    return (email ?? '').trim().toLowerCase();
  }

  /** 이름 정규화(연속 공백 1칸) */
  private normName(name: string) {
    return (name ?? '').trim().replace(/\s+/g, ' ');
  }

  /** KU 도메인 확인(대소문자 무시) */
  private isKkuEmail(email: string) {
    return /^[^@\s]+@kku\.ac\.kr$/i.test(email);
  }

  /** 엔티티 → 안전 타입(SafeUser) */
  public toSafeUser(u: User): SafeUser {
    return {
      id: String(u.id),
      email: u.email,
      name: u.name,
      role: u.role as any,
    };
  }


  /* PART D. 생성/가입 ------------------------------------------*/

  /**
   * 회원가입(일반 사용자)
   * - 비밀번호 최소 길이 가드
   * - 이메일 중복(soft delete 제외) 선확인
   * - bcrypt 라운드 Config 기반
   * - unique 충돌 → EMAIL_IN_USE
   */
  async create(dto: { email: string; name: string; password: string }): Promise<SafeUser> {
    const email = this.normEmail(dto.email);
    const name = this.normName(dto.name);

    if (!dto.password || dto.password.length < 4) {
      throw new ConflictException('PASSWORD_TOO_SHORT');
    }

    // 사전 중복(soft delete 제외)
    const exists = await this.usersRepository.findOne({
      where: { email, deletedAt: IsNull() },
      select: { id: true },
    });
    if (exists) throw new ConflictException('EMAIL_IN_USE');

    const rounds = Number(this.cfg.get('BCRYPT_SALT_ROUNDS') ?? 10);
    const passwordHash = await bcrypt.hash(dto.password, rounds);

    const user = this.usersRepository.create({
      email,
      name,
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
        e?.code === 'ER_DUP_ENTRY' || e?.errno === 1062 ||
        msg.includes('UNIQUE') || msg.includes('SQLITE_CONSTRAINT')
      ) {
        throw new ConflictException('EMAIL_IN_USE');
      }
      throw e;
    }

    // eslint-disable-next-line no-console
    this.logger.debug(`signup ok: ${user.email}`);
    return this.toSafeUser(user);
  }

  /* PART E. 조회(로그인 전용/일반/UUID/lookup) ------------------*/

  /**
   * 로그인 전용: passwordHash 포함 조회
   * - 엔티티에서 passwordHash는 select:false 가정
   * - DB 콜레이션이 CI면 LOWER() 불필요 (사전 소문자 정규화)
   * - soft delete 제외
   */
  async findByEmailWithHash(email: string): Promise<User | null> {
    const e = this.normEmail(email);
    return this.usersRepository
      .createQueryBuilder('u')
      .where('u.email = :e', { e })
      .andWhere('u.deletedAt IS NULL')
      // 🔴 꼭 포함: 엔티티에서 passwordHash가 select:false일 수 있으므로 addSelect 필요
      .addSelect('u.passwordHash')
      .getOne();
  }



  /**
   * 일반 조회(안전 타입)
   * - passwordHash 불포함
   * - soft delete 제외
   */
  async findByEmail(email: string): Promise<SafeUser | null> {
    const e = this.normEmail(email);
    const u = await this.usersRepository.findOne({
      where: { email: e, deletedAt: IsNull() },
    });
    return u ? this.toSafeUser(u) : null;
  }

  /** ID로 조회(안전 타입) — UUID, soft delete 제외 */
  async findOne(id: string): Promise<SafeUser> {
    const user = await this.usersRepository.findOne({
      where: { id, deletedAt: IsNull() },
    });
    if (!user) throw new NotFoundException('User not found');
    return this.toSafeUser(user);
  }

  /** (AuthService 호환) UUID 조회(안전 타입), soft delete 제외 */
  async findOneByUuid(uuid: string): Promise<SafeUser | null> {
    const user = await this.usersRepository.findOne({
      where: { id: uuid, deletedAt: IsNull() },
    });
    return user ? this.toSafeUser(user) : null;
  }

  /**
   * 통합 사용자 조회 (/api/v1/users/lookup?query=...)
   * - 이메일(@kku.ac.kr) 우선(대소문자 무시)
   * - 아니면 이름 완전일치(대소문자 무시)
   * - soft delete 제외
   */
  async lookupByQuery(
    rawInput: string,
  ): Promise<{ id: string; name?: string; email?: string }> {
    const raw = this.normEmail(rawInput); // 소문자/trim
    if (!raw) throw new NotFoundException('USER_NOT_FOUND');

    // 1) 이메일 형식이면 이메일 우선
    if (this.isKkuEmail(raw)) {
      const byEmail = await this.usersRepository
        .createQueryBuilder('u')
        .select(['u.id AS id', 'u.name AS name', 'u.email AS email'])
        .where('u.email = :raw', { raw })
        .andWhere('u.deletedAt IS NULL')
        .orderBy('u.id', 'ASC')
        .limit(1)
        .getRawOne<RawUserRow>();

      if (byEmail) {
        return {
          id: byEmail.id,
          name: byEmail.name ?? undefined,
          email: byEmail.email ?? undefined,
        };
      }
      throw new NotFoundException('USER_NOT_FOUND');
    }

    // 2) 이메일 형식이 아니면 이름 완전일치
    const byName = await this.usersRepository
      .createQueryBuilder('u')
      .select(['u.id AS id', 'u.name AS name', 'u.email AS email'])
      .where('u.name = :raw', { raw })
      .andWhere('u.deletedAt IS NULL')
      .orderBy('u.id', 'ASC')
      .limit(1)
      .getRawOne<RawUserRow>();

    if (byName) {
      return {
        id: byName.id,
        name: byName.name ?? undefined,
        email: byName.email ?? undefined,
      };
    }

    throw new NotFoundException('USER_NOT_FOUND');
  }

  /* PART F. 대학 인증 플래그 갱신(멱등) ------------------------*/

  /**
   * 대학교 인증 완료 표시
   * - 이메일 기준으로 유저를 찾아 인증 플래그/학교명 업데이트
   * - soft delete 제외
   * - 멱등성 보장
   */
  async markUniversityVerifiedByEmail(email: string, universityName: string) {
    const norm = this.normEmail(email);
    const uni = this.normName(universityName);

    const user = await this.usersRepository.findOne({
      where: { email: norm, deletedAt: IsNull() },
    });
    if (!user) {
      return { ok: false as const, reason: 'user_not_found' as const };
    }

    // 멱등
    if (user.universityVerified && (user.universityName ?? '') === uni) {
      return { ok: true as const, already: true as const, source: 'db' as const };
    }
    user.universityVerified = true;
    user.universityName = uni;
    await this.usersRepository.save(user);

    return { ok: true as const, updated: true as const, source: 'db' as const };
  }

  /* PART G. 디버그 유틸 ----------------------------------------*/

  /** 디버그: 접속 DB/유저 수 */
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

  /** 디버그: 최근 가입 이메일 200개 */
  async debugListEmails() {
    try {
      const rows = await this.dataSource.query(
        `SELECT id, email FROM users WHERE deletedAt IS NULL ORDER BY createdAt DESC LIMIT 200;`,
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
