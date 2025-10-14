// src/modules/auth/auth.service.ts
import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
  import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { randomUUID } from 'crypto';

import { UsersService } from '../users/users.service';
import { User, UserRole } from '../users/entities/user.entity';
import type { SafeUser } from './types/user.types';
import { RefreshDto } from './dto/refresh.dto';

type JwtPayload = {
  sub: string;   // user id (UUID)
  email: string;
  role: UserRole;
};

@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    private readonly cfg: ConfigService,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {}

  // --------- 회원가입 ---------
  async register(dto: { email: string; password: string; name?: string }): Promise<{
    accessToken: string;
    refreshToken: string;
    user: SafeUser;
  }> {
    const email = dto.email.trim().toLowerCase();

    // 중복 이메일 체크 (삭제되지 않은 계정만 대상)
    const exists = await this.userRepo.findOne({
      where: { email, deletedAt: IsNull() },
      select: { id: true }, // 가벼운 조회
    });
    if (exists) {
      throw new BadRequestException('EMAIL_TAKEN');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);

    // 기본값: 이름 없으면 이메일 앞부분 사용
    const name = (dto.name ?? email.split('@')[0]).trim();

    const newUser = this.userRepo.create({
      id: randomUUID(),
      email,
      name,
      passwordHash,
      role: (UserRole as any).USER ?? 'USER',
      // reputation, universityVerified 등은 엔티티의 디폴트를 사용
    });

    await this.userRepo.save(newUser);

    // UsersService의 toSafeUser 헬퍼 재사용 (프로젝트 기존 구조 호환)
    const safe: SafeUser =
      (this.users as any)['toSafeUser']
        ? (this.users as any)['toSafeUser'](newUser)
        : {
            id: newUser.id,
            email: newUser.email,
            name: newUser.name,
            role: newUser.role as any,
          };

    // 회원가입 후 즉시 토큰 발급
    const payload: JwtPayload = {
      sub: String(safe.id),
      email: safe.email!,
      role: safe.role! as unknown as UserRole,
    };
    const accessToken = this.signAccessToken(payload);
    const refreshToken = this.signRefreshToken({ sub: String(safe.id) });

    return { accessToken, refreshToken, user: safe };
  }

  // --------- 로그인 ---------
  /** 이메일/패스워드 검증 → SafeUser 반환 */
  private async validateUser(email: string, password: string): Promise<SafeUser> {
    const user = await this.users.findByEmailWithHash(email.toLowerCase());
    if (!user?.passwordHash) {
      throw new UnauthorizedException('INVALID_CREDENTIALS');
    }
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) throw new UnauthorizedException('INVALID_CREDENTIALS');

    return (this.users as any)['toSafeUser']
      ? (this.users as any)['toSafeUser'](user)
      : ({
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role as any,
        } as SafeUser);
  }

  /** 액세스 토큰 발급 */
  private signAccessToken(payload: JwtPayload): string {
    const secret = this.cfg.get<string>('JWT_ACCESS_SECRET', 'access_secret');
    const expiresIn = this.cfg.get<string>('JWT_ACCESS_EXPIRES_IN', '15m'); // 예: 15m
    return this.jwt.sign(payload, { secret, expiresIn });
  }

  /** 리프레시 토큰 발급 (stateless) */
  private signRefreshToken(payload: Pick<JwtPayload, 'sub'>): string {
    const secret = this.cfg.get<string>('JWT_REFRESH_SECRET', 'refresh_secret');
    const expiresIn = this.cfg.get<string>('JWT_REFRESH_EXPIRES_IN', '14d'); // 예: 14d
    return this.jwt.sign(payload, { secret, expiresIn });
  }

  /** 로그인 */
  async login(
    email: string,
    password: string,
  ): Promise<{ accessToken: string; refreshToken: string; user: SafeUser }> {
    const safe = await this.validateUser(email, password);

    const payload: JwtPayload = {
      sub: String(safe.id),
      email: safe.email!,
      role: safe.role! as unknown as UserRole,
    };

    const accessToken = this.signAccessToken(payload);
    const refreshToken = this.signRefreshToken({ sub: String(safe.id) });

    return { accessToken, refreshToken, user: safe };
  }

  /** 리프레시 (토큰 재발급) */
  async refresh(dto: RefreshDto): Promise<{
    accessToken: string;
    refreshToken: string;
    user: SafeUser;
  }> {
    if (!dto?.refreshToken) {
      throw new BadRequestException('MISSING_REFRESH_TOKEN');
    }

    const secret = this.cfg.get<string>('JWT_REFRESH_SECRET', 'refresh_secret');
    let decoded: { sub?: string | number } | null = null;

    try {
      decoded = this.jwt.verify(dto.refreshToken, { secret }) as any;
    } catch {
      throw new UnauthorizedException('INVALID_REFRESH_TOKEN');
    }

    const userId = decoded?.sub;
    if (userId == null) throw new UnauthorizedException('INVALID_REFRESH_TOKEN');

    const safeUser = await this.users.findOne(String(userId));
    const payload: JwtPayload = {
      sub: String(safeUser.id),
      email: safeUser.email!,
      role: safeUser.role! as unknown as UserRole,
    };

    // 토큰 회전
    const newAccess = this.signAccessToken(payload);
    const newRefresh = this.signRefreshToken({ sub: String(safeUser.id) });

    return { accessToken: newAccess, refreshToken: newRefresh, user: safeUser };
  }
}
