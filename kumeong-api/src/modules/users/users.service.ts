// src/modules/users/users.service.ts
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { DataSource, Repository } from 'typeorm';
import { User, UserRole } from './entities/user.entity';
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
    // passwordHash 컬럼만 제거해서 반환
    const { passwordHash, ...safe } = u as any;
    return safe as SafeUser;
  }

  /** 서버 시작 시 테스트용 유저 등록 (즉시 로그인 가능) */
  private initTestUser() {
    const testEmail = this.normEmail('student@kku.ac.kr');
    if (this.testUsersByEmail.has(testEmail)) return;

    const rounds = this.cfg.get<number>('BCRYPT_SALT_ROUNDS', 10);
    const passwordHash = bcrypt.hashSync('password1234', rounds);

    // 엔티티 정의에 맞춰 id는 number 사용(메모리 전용이므로 0 사용)
    const user: User = {
      id: 0,
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

    // id/타임스탬프는 데코레이터가 관리 → 직접 지정하지 않음
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
    console.log('[UsersService] 🟢 회원가입 완료 (DB):', user.email);

    return this.toSafeUser(user);
  }

  /** 로그인: 해시 포함 원본 조회 */
  async findByEmailWithHash(email: string): Promise<User | null> {
    const norm = this.normEmail(email);

    // 1) 테스트 유저 먼저
    const testUser = this.testUsersByEmail.get(norm);
    if (testUser) {
      console.log('[UsersService] ✨ 메모리에서 테스트 유저 조회:', testUser.email);
      return testUser;
    }

    // 2) 실제 DB 조회 (passwordHash는 엔티티 속성명으로 addSelect)
    const user = await this.usersRepository
      .createQueryBuilder('user')
      .addSelect('user.passwordHash') // ✅ 엔티티 속성명 사용
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
  async findOne(id: number): Promise<SafeUser> {
    // ✅ 테스트 유저 폴백: JWT sub=0인 경우 커버
    if (id === 0) {
      const test = this.testUsersByEmail.get(this.normEmail('student@kku.ac.kr'));
      if (test) return this.toSafeUser(test);
    }

    const user = await this.usersRepository.findOne({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return this.toSafeUser(user);
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
}
