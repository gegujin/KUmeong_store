// src/modules/users/users.service.ts
import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { randomUUID } from 'crypto';
import { UserRole } from './entities/user.entity';
import type { SafeUser } from '../auth/types/user.types'; 

/** 내부 저장용 레코드(해시 포함) */
export interface UserRecord {
  id: string;
  email: string;
  name: string;
  passwordHash: string;
  role: UserRole;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class UsersService {
  private usersById = new Map<string, UserRecord>();
  private usersByEmail = new Map<string, UserRecord>();

  constructor(private readonly cfg: ConfigService) {
    this.initTestUser(); // 서버 시작 시 테스트 유저 등록
  }

  private normEmail(email: string) {
    return (email ?? '').trim().toLowerCase();
  }

  private toSafeUser(u: UserRecord): SafeUser {
    const { passwordHash, ...safe } = u;
    return safe as SafeUser;
  }

  /** 서버 시작 시 테스트용 유저 등록 */
  private async initTestUser() {
    const testEmail = 'student@kku.ac.kr';
    const testName = 'KKU Student';
    const testPassword = 'password1234';

    if (!this.usersByEmail.has(this.normEmail(testEmail))) {
      const rounds = this.cfg.get<number>('BCRYPT_SALT_ROUNDS', 10);
      const passwordHash = await bcrypt.hash(testPassword, rounds);
      const now = new Date();

      const user: UserRecord = {
        id: randomUUID(),
        email: this.normEmail(testEmail),
        name: testName,
        passwordHash,
        role: UserRole.USER,
        createdAt: now,
        updatedAt: now,
      };

      this.usersById.set(user.id, user);
      this.usersByEmail.set(user.email, user);

      console.log('[UsersService] 초기 테스트 유저 등록 완료:', user.email);
    }
  }

  /** 회원 생성 (해시 저장), 반환은 안전 객체 */
  async create(dto: { email: string; name: string; password: string }): Promise<SafeUser> {
    const email = this.normEmail(dto.email);
    if (this.usersByEmail.has(email)) {
      throw new ConflictException('Email already in use');
    }

    const rounds = this.cfg.get<number>('BCRYPT_SALT_ROUNDS', 10);
    const passwordHash = await bcrypt.hash(dto.password, rounds);
    const now = new Date();

    const user: UserRecord = {
      id: randomUUID(),
      email,
      name: (dto.name ?? '').trim().replace(/\s+/g, ' '),
      passwordHash,
      role: UserRole.USER,
      createdAt: now,
      updatedAt: now,
    };

    this.usersById.set(user.id, user);
    this.usersByEmail.set(email, user);

    return this.toSafeUser(user);
  }

  /** 로그인용: 해시 포함 원본 레코드 (AuthService가 사용) */
  async findByEmailWithHash(email: string): Promise<UserRecord | null> {
    const user = this.usersByEmail.get(this.normEmail(email)) ?? null;
    console.log('[UsersService] DB에서 조회:', user ? user.email : null);
    return user;
  }

  /** 조회용: 해시 제거 */
  async findByEmail(email: string): Promise<SafeUser | null> {
    const u = await this.findByEmailWithHash(email);
    return u ? this.toSafeUser(u) : null;
  }

  /** ID로 조회(해시 제거) */
  async findOne(id: string): Promise<SafeUser> {
    const u = this.usersById.get(id);
    if (!u) throw new NotFoundException('User not found');
    return this.toSafeUser(u);
  }
}
