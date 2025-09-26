// src/modules/auth/jwt.strategy.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy, type JwtFromRequestFunction } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../users/users.service';
import { UserRole } from '../users/entities/user.entity';
import type { SafeUser } from './types/user.types';

interface JwtPayload {
  sub: string;   // ← 문자열 유지 (표준)
  email: string;
  iat?: number;
  exp?: number;
  aud?: string | string[];
  iss?: string;
}

// ── 토큰 추출: Authorization(표준) ▶ x-access-token ▶ ?access_token=
const fromAuthHeader = ExtractJwt.fromAuthHeaderAsBearerToken();
const fromXHeader = ExtractJwt.fromHeader('x-access-token');
const fromQuery = ExtractJwt.fromUrlQueryParameter('access_token');
const jwtExtractor: JwtFromRequestFunction = (req) =>
  fromAuthHeader(req) || fromXHeader(req) || fromQuery(req);

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    cfg: ConfigService,
    private readonly users: UsersService,
  ) {
    super({
      jwtFromRequest: (req) =>
        ExtractJwt.fromAuthHeaderAsBearerToken()(req) ||
        ExtractJwt.fromHeader('x-access-token')(req) ||
        ExtractJwt.fromUrlQueryParameter('access_token')(req),
      ignoreExpiration: false,
      secretOrKey: cfg.get<string>('JWT_SECRET'),
      issuer: cfg.get<string>('JWT_ISSUER') || undefined,
      audience: cfg.get<string>('JWT_AUDIENCE') || undefined,
    });
  }

  // req.user 에 들어갈 최종 형태
  async validate(payload: JwtPayload): Promise<SafeUser> {
    if (!payload?.sub || !payload?.email) {
      throw new UnauthorizedException('Invalid token payload');
    }

    // 🔧 sub(string) → number로 변환
    const userId = Number(payload.sub);
    if (!Number.isFinite(userId)) {
      throw new UnauthorizedException('Invalid token subject');
    }

    // UsersService.findOne은 number를 받음
    const u = await this.users.findOne(userId);

    // 혹시 과거 데이터에 role이 없을 수 있으니 마지막 방어
    return { id: u.id, email: u.email, role: u.role ?? UserRole.USER };
  }
}
