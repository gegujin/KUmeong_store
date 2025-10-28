// src/modules/auth/auth.service.ts
import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
  Logger, // ★추가
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

// ★추가: 표준화된 결과 코드
enum AuthResultCode {
  OK = 'OK',
  EMAIL_TAKEN = 'EMAIL_TAKEN',
  USER_NOT_FOUND = 'USER_NOT_FOUND',
  USER_DELETED = 'USER_DELETED',
  PASSWORD_HASH_MISSING = 'PASSWORD_HASH_MISSING',
  PASSWORD_MISMATCH = 'PASSWORD_MISMATCH',
  INVALID_REFRESH_TOKEN = 'INVALID_REFRESH_TOKEN',
  MISSING_REFRESH_TOKEN = 'MISSING_REFRESH_TOKEN',
  SYS_ERROR = 'SYS_ERROR',
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name); // ★추가
  private readonly debug = this.cfg.get<boolean>('AUTH_DEBUG') ?? true; // ★추가

  constructor(
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    private readonly cfg: ConfigService,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {}

  // --------- 공통 로깅 헬퍼 --------- // ★추가
  private logResult(
    action: 'REGISTER' | 'LOGIN' | 'REFRESH',
    result: AuthResultCode,
    meta: Record<string, any> = {},
  ) {
    const base = { action, result, ...meta };
    if (result === AuthResultCode.OK) this.logger.log(base);
    else this.logger.warn(base);
  }

  // --------- 회원가입 ---------
  async register(dto: { email: string; password: string; name?: string }): Promise<{
    accessToken: string;
    refreshToken: string;
    user: SafeUser;
  }> {
    const email = dto.email.trim().toLowerCase();
    try {
      const exists = await this.userRepo.findOne({
        where: { email, deletedAt: IsNull() },
        select: { id: true, deletedAt: true },
      });
      if (exists) {
        this.logResult('REGISTER', AuthResultCode.EMAIL_TAKEN, { email });
        throw new BadRequestException(AuthResultCode.EMAIL_TAKEN);
      }

      const passwordHash = await bcrypt.hash(dto.password, 10);
      const name = (dto.name ?? email.split('@')[0]).trim();

      const newUser = this.userRepo.create({
        id: randomUUID(),
        email,
        name,
        passwordHash,
        role: (UserRole as any).USER ?? 'USER',
      });
      await this.userRepo.save(newUser);

      const safe: SafeUser = this.users.toSafeUser(newUser);

      const payload: JwtPayload = {
        sub: String(safe.id),
        email: safe.email!,
        role: safe.role! as unknown as UserRole,
      };
      const accessToken = this.signAccessToken(payload);
      const refreshToken = this.signRefreshToken({ sub: String(safe.id) });

      this.logResult('REGISTER', AuthResultCode.OK, { userId: safe.id, email });
      return { accessToken, refreshToken, user: safe };
    } catch (e) {
      if (!(e instanceof BadRequestException)) {
        this.logResult('REGISTER', AuthResultCode.SYS_ERROR, { email, error: `${e}` });
      }
      throw e;
    }
  }

  // --------- 로그인 ---------
  /** 이메일/패스워드 검증 → SafeUser 반환 */
  private async validateUser(emailRaw: string, password: string): Promise<SafeUser> {
    const email = emailRaw.toLowerCase();
    const user = await this.users.findByEmailWithHash(email);

    if (!user) {
      this.logResult('LOGIN', AuthResultCode.USER_NOT_FOUND, { email });
      throw new UnauthorizedException('INVALID_CREDENTIALS');
    }
    if ((user as any).deletedAt) {
      this.logResult('LOGIN', AuthResultCode.USER_DELETED, { email, userId: user.id });
      throw new UnauthorizedException('INVALID_CREDENTIALS');
    }
    if (!user.passwordHash) {
      this.logResult('LOGIN', AuthResultCode.PASSWORD_HASH_MISSING, { email, userId: user.id });
      throw new UnauthorizedException('INVALID_CREDENTIALS');
    }

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      // 비밀번호 자체는 절대 로그에 남기지 않음
      const meta = this.debug ? { email, userId: user.id, bcryptCompare: false } : { email, userId: user.id };
      this.logResult('LOGIN', AuthResultCode.PASSWORD_MISMATCH, meta);
      throw new UnauthorizedException('INVALID_CREDENTIALS');
    }

    this.logResult('LOGIN', AuthResultCode.OK, { email, userId: user.id });
    return (this.users as any)['toSafeUser']
      ? (this.users as any)['toSafeUser'](user)
      : ({ id: user.id, email: user.email, name: user.name, role: user.role as any } as SafeUser);
  }

  /** 액세스 토큰 발급 */
  private signAccessToken(payload: JwtPayload): string {
    const secret = this.cfg.get<string>('JWT_ACCESS_SECRET', 'access_secret');
    const expiresIn = this.cfg.get<string>('JWT_ACCESS_EXPIRES_IN', '15m');
    const issuer = this.cfg.get<string>('JWT_ISSUER');      // ✅ 추가
    const audience = this.cfg.get<string>('JWT_AUDIENCE');  // ✅ 추가

    return this.jwt.sign(payload, {
      secret,
      expiresIn,
      ...(issuer ? { issuer } : {}),
      ...(audience ? { audience } : {}),
    });
  }


  /** 리프레시 토큰 발급 (stateless) */
  private signRefreshToken(payload: Pick<JwtPayload, 'sub'>): string {
    const secret = this.cfg.get<string>('JWT_REFRESH_SECRET', 'refresh_secret');
    const expiresIn = this.cfg.get<string>('JWT_REFRESH_EXPIRES_IN', '14d');
    return this.jwt.sign(payload, { secret, expiresIn });
  }

  /** 로그인 */
  async login(
    email: string,
    password: string,
  ): Promise<{ accessToken: string; refreshToken: string; user: SafeUser }> {
    try {
      const safe = await this.validateUser(email, password);
      const payload: JwtPayload = { sub: String(safe.id), email: safe.email!, role: safe.role! as unknown as UserRole };
      const accessToken = this.signAccessToken(payload);
      const refreshToken = this.signRefreshToken({ sub: String(safe.id) });
      return { accessToken, refreshToken, user: safe };
    } catch (e) {
      // UnauthorizedException 등 상위로 던지되, 시스템 에러면 추가 로그
      if (!(e instanceof UnauthorizedException)) {
        this.logResult('LOGIN', AuthResultCode.SYS_ERROR, { email, error: `${e}` });
      }
      throw e;
    }
  }

  /** 리프레시 (토큰 재발급) */
  async refresh(dto: RefreshDto): Promise<{
    accessToken: string;
    refreshToken: string;
    user: SafeUser;
  }> {
    if (!dto?.refreshToken) {
      this.logResult('REFRESH', AuthResultCode.MISSING_REFRESH_TOKEN);
      throw new BadRequestException(AuthResultCode.MISSING_REFRESH_TOKEN);
    }

    const secret = this.cfg.get<string>('JWT_REFRESH_SECRET', 'refresh_secret');
    let decoded: { sub?: string | number } | null = null;

    try {
      decoded = this.jwt.verify(dto.refreshToken, { secret }) as any;
    } catch (e) {
      this.logResult('REFRESH', AuthResultCode.INVALID_REFRESH_TOKEN, { error: `${e}` });
      throw new UnauthorizedException(AuthResultCode.INVALID_REFRESH_TOKEN);
    }

    const userId = decoded?.sub;
    if (userId == null) {
      this.logResult('REFRESH', AuthResultCode.INVALID_REFRESH_TOKEN, { reason: 'no_sub' });
      throw new UnauthorizedException(AuthResultCode.INVALID_REFRESH_TOKEN);
    }

    try {
      const safeUser = await this.users.findOne(String(userId));
      const payload: JwtPayload = {
        sub: String(safeUser.id),
        email: safeUser.email!,
        role: safeUser.role! as unknown as UserRole,
      };
      const newAccess = this.signAccessToken(payload);
      const newRefresh = this.signRefreshToken({ sub: String(safeUser.id) });
      this.logResult('REFRESH', AuthResultCode.OK, { userId: safeUser.id });
      return { accessToken: newAccess, refreshToken: newRefresh, user: safeUser };
    } catch (e) {
      this.logResult('REFRESH', AuthResultCode.SYS_ERROR, { userId, error: `${e}` });
      throw e;
    }
  }

  // ---------- (선택) 개발용: 비번 리셋 헬퍼 ----------
  async resetPasswordDev(email: string, newPassword: string) { // ★옵션
    if (this.cfg.get<string>('NODE_ENV') !== 'development') {
      throw new ForbiddenException('dev only');
    }
    const user = await this.userRepo.findOne({ where: { email: email.toLowerCase(), deletedAt: IsNull() } });
    if (!user) throw new NotFoundException('user not found');

    user.passwordHash = await bcrypt.hash(newPassword, 10);
    await this.userRepo.save(user);
    this.logResult('LOGIN', AuthResultCode.OK, { devReset: true, email, userId: user.id });
  }
}
