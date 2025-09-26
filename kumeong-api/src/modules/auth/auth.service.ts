// src/modules/auth/auth.service.ts
import { Injectable, UnauthorizedException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { UsersService } from '../users/users.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ConfigService } from '@nestjs/config';
import { UserRole } from '../users/entities/user.entity';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    private readonly cfg: ConfigService,
  ) {}

  async register(dto: RegisterDto) {
    const newUser = await this.users.create(dto);
    const accessToken = await this.signToken(newUser.id, newUser.email, newUser.role);

    this.logger.log(`회원가입 완료: ${newUser.email}`);

    return {
      accessToken,
      user: {
        id: newUser.id,
        email: newUser.email,
        role: newUser.role,
        name: dto.name?.trim() ?? '',
      },
    };
  }

  async login(dto: LoginDto) {
    this.logger.log(`로그인 시도: ${dto.email}`);

    const user = await this.users.findByEmailWithHash(dto.email);
    this.logger.debug(`조회된 유저: ${user ? user.email : 'null'}`);

    if (!user) {
      this.logger.warn(`유저 없음: ${dto.email}`);
      throw new UnauthorizedException('Invalid credentials');
    }

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    this.logger.debug(`bcrypt 비교 결과: ${ok}`);

    if (!ok) {
      this.logger.warn(`비밀번호 불일치: ${dto.email}`);
      throw new UnauthorizedException('Invalid credentials');
    }

    const accessToken = await this.signToken(user.id, user.email, user.role);
    this.logger.log(`로그인 성공: ${dto.email}`);

    return {
      accessToken,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        name: user.name,
      },
    };
  }

  /** JWT 서명: 호출부와 일치( id, email, role ) + payload에 email 포함 */
  private async signToken(
    userId: string | number,
    email: string,
    role?: UserRole | string,
  ): Promise<string> {
    const issuer = this.cfg.get<string>('JWT_ISSUER');
    const audience = this.cfg.get<string>('JWT_AUDIENCE');
    const expiresIn = this.cfg.get<string>('JWT_EXPIRES') ?? '7d';

    const payload = {
      sub: String(userId),    // 문자열 고정
      email,                  // ✅ validate에서 사용할 핵심
      role: (role ?? 'USER') as string,
    };

    return this.jwt.signAsync(payload, {
      ...(issuer ? { issuer } : {}),
      ...(audience ? { audience } : {}),
      expiresIn,
    });
  }
}
