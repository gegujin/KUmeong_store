// src/modules/users/users.service.ts
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { randomUUID } from 'crypto';
import { User, UserRole } from './entities/user.entity';
import { DataSource, Repository } from 'typeorm';
import type { SafeUser } from '../auth/types/user.types';

@Injectable()
export class UsersService {
  /** 테스트용 유저 (메모리 저장) */
  private testUsersByEmail = new Map<string, User>();
  /** 실제 회원가입 유저 Repository (DB 연결용) */
  private usersRepository: Repository<User>;

  constructor(
    private readonly cfg: ConfigService,
    private readonly dataSource: DataSource,
  ) {
    this.usersRepository = this.dataSource.getRepository(User);
    this.initTestUser(); // 동기 등록
  }

  /** 이메일 정규화 */
  private normEmail(email: string) {
    return (email ?? '').trim().toLowerCase();
  }

  /** 비밀번호 제외 안전 유저 타입 변환 */
  private toSafeUser(u: User): SafeUser {
    const { passwordHash, ...safe } = u;
    return safe as SafeUser;
  }

  /** 서버 시작 시 테스트용 유저 등록 (즉시 로그인 가능) */
  private initTestUser() {
    const testEmail = this.normEmail('student@kku.ac.kr');
    if (this.testUsersByEmail.has(testEmail)) return;

    const rounds = this.cfg.get<number>('BCRYPT_SALT_ROUNDS', 10);
    const passwordHash = bcrypt.hashSync('password1234', rounds);
    const now = new Date();

    const user: User = {
      id: randomUUID(),
      email: testEmail,
      name: 'KKU Student',
      passwordHash,
      reputation: 0,
      role: UserRole.USER,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      products: [],
    };

    this.testUsersByEmail.set(testEmail, user);
    console.log('[UsersService] ✅ 테스트 유저 등록 완료:', user.email);
  }

  /** 회원가입: 일반 유저용 */
  async create(dto: { email: string; name: string; password: string }): Promise<SafeUser> {
    const email = this.normEmail(dto.email);

    // 테스트 유저는 회원가입 막기
    if (this.testUsersByEmail.has(email)) {
      throw new ConflictException('This is a reserved test account');
    }

    // 최소 비밀번호 길이 4자로 허용
    if (!dto.password || dto.password.length < 4) {
      throw new ConflictException('Password must be at least 4 characters');
    }

    // DB 중복 체크
    const exists = await this.usersRepository.findOne({ where: { email } });
    if (exists) throw new ConflictException('Email already in use');

    const rounds = this.cfg.get<number>('BCRYPT_SALT_ROUNDS', 10);
    const passwordHash = await bcrypt.hash(dto.password, rounds);

    const user = this.usersRepository.create({
      id: randomUUID(),
      email,
      name: (dto.name ?? '').trim().replace(/\s+/g, ' '),
      passwordHash,
      reputation: 0,
      role: UserRole.USER,
      createdAt: new Date(),
      updatedAt: new Date(),
      deletedAt: null,
    });

    await this.usersRepository.save(user);
    console.log('[UsersService] 🟢 회원가입 완료 (DB):', user.email);

    return this.toSafeUser(user);
  }

  /** 로그인: 해시 포함 원본 조회 */
  async findByEmailWithHash(email: string): Promise<User | null> {
    const norm = this.normEmail(email);

    // 테스트 유저 먼저 확인
    const testUser = this.testUsersByEmail.get(norm);
    if (testUser) {
      console.log('[UsersService] ✨ 메모리에서 테스트 유저 조회:', testUser.email);
      return testUser;
    }

    // 실제 DB 조회 (passwordHash 포함)
    const user = await this.usersRepository
      .createQueryBuilder('user')
      .addSelect('user.password_hash')
      .where('user.email = :email', { email: norm })
      .getOne();

    console.log('[UsersService] 🔍 DB에서 조회:', user ? user.email : null);
    return user ?? null;
  }

  /** 조회용: 안전 유저 타입 */
  async findByEmail(email: string): Promise<SafeUser | null> {
    const u = await this.findByEmailWithHash(email);
    return u ? this.toSafeUser(u) : null;
  }

  /** ID로 조회(안전 유저 타입) */
  async findOne(id: string): Promise<SafeUser> {
    const user = await this.usersRepository.findOne({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return this.toSafeUser(user);
  }
}
