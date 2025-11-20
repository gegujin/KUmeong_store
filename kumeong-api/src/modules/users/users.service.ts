// src/modules/users/users.service.ts
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { DataSource, Repository, IsNull } from 'typeorm';
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
  public toSafeUser(u: User): SafeUser {
    const { passwordHash, ...safe } = u as any;
    (safe as any).id = String(u.id);
    return safe as SafeUser;
  }

  /** 회원가입 */
  async create(dto: { email: string; name: string; password: string }): Promise<SafeUser> {
    const email = this.normEmail(dto.email);

    if (!dto.password || dto.password.length < 4) {
      throw new ConflictException('PASSWORD_TOO_SHORT');
    }

    const exists = await this.usersRepository.findOne({
      where: { email, deletedAt: IsNull() },
    });
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

    await this.usersRepository.save(user);
    return this.toSafeUser(user);
  }

  /** 🔥 로그인용: 해시 포함 유저 조회 — queryBuilder 버전 (정석) */
  async findByEmailWithHash(email: string) {
    const e = (email ?? '').trim().toLowerCase();

    return this.usersRepository
      .createQueryBuilder('u')
      .where('u.email = :e', { e })
      .andWhere('u.deletedAt IS NULL')
      .addSelect('u.passwordHash')
      .getOne();
  }

  /** 이메일 조회 (safe type) */
  async findByEmail(email: string): Promise<SafeUser | null> {
    const u = await this.findByEmailWithHash(email);
    return u ? this.toSafeUser(u) : null;
  }

  /** ID로 조회 */
  async findOne(id: string): Promise<SafeUser> {
    const user = await this.usersRepository.findOne({ where: { id, deletedAt: IsNull() } });
    if (!user) throw new NotFoundException('User not found');
    return this.toSafeUser(user);
  }

  /** AuthService 전용 UUID 조회 */
  async findOneByUuid(uuid: string): Promise<SafeUser | null> {
    const user = await this.usersRepository.findOne({
      where: { id: uuid, deletedAt: IsNull() },
    });
    return user ? this.toSafeUser(user) : null;
  }

  /** 통합 조회 API */
  async lookupByQuery(rawInput: string) {
    const raw = (rawInput ?? '').trim().toLowerCase();
    if (!raw) throw new NotFoundException('USER_NOT_FOUND');

    const looksEmail = /^[^@\s]+@kku\.ac\.kr$/.test(raw);

    if (looksEmail) {
      const byEmail = await this.usersRepository
        .createQueryBuilder('u')
        .select(['u.id AS id', 'u.name AS name', 'u.email AS email'])
        .where('LOWER(u.email) = :raw', { raw })
        .orderBy('u.id', 'ASC')
        .limit(1)
        .getRawOne<RawUserRow>();

      if (byEmail) return byEmail;
      throw new NotFoundException('USER_NOT_FOUND');
    }

    const byName = await this.usersRepository
      .createQueryBuilder('u')
      .select(['u.id AS id', 'u.name AS name', 'u.email AS email'])
      .where('LOWER(u.name) = :raw', { raw })
      .orderBy('u.id', 'ASC')
      .limit(1)
      .getRawOne<RawUserRow>();

    if (byName) return byName;

    throw new NotFoundException('USER_NOT_FOUND');
  }

  /** 대학교 인증 */
  async markUniversityVerifiedByEmail(email: string, universityName: string) {
    const norm = this.normEmail(email);

    const user = await this.usersRepository.findOne({
      where: {
        email: norm,
        deletedAt: IsNull(),
      },
    });

    if (!user) {
      return { ok: false as const, reason: 'user_not_found' as const };
    }

    if (user.universityVerified && user.universityName === universityName) {
      return { ok: true as const, already: true as const };
    }

    user.universityVerified = true;
    user.universityName = universityName;
    await this.usersRepository.save(user);

    return { ok: true as const, updated: true as const };
  }

  /** DB 디버그 */
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

  /** 이메일 리스트 디버그 */
  async debugListEmails() {
    try {
      const rows = await this.dataSource.query(
        `SELECT id, email FROM users ORDER BY createdAt DESC LIMIT 200;`,
      );
      return {
        count: rows.length,
        emails: rows.map((r: any) => ({
          id: String(r.id),
          email: String(r.email),
        })),
      };
    } catch (e: any) {
      return { error: e?.message ?? String(e) };
    }
  }
}

