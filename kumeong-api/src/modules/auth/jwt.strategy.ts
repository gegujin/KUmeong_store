// src/modules/auth/jwt.strategy.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../users/users.service';

export type JwtPayload = {
  sub: string;         // UUID/숫자 문자열 허용
  email?: string;
  role?: string;
  type?: 'access' | 'refresh';
  iat?: number;
  exp?: number;
};

export type SafeUser = {
  id: string;
  email: string;
  role?: string;
  name?: string;
};

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private readonly users: UsersService,
  ) {
    // ✅ 안전 캐스팅 + 공백 제거
    const ISSUER = String(config.get('JWT_ISSUER') ?? '').trim() || undefined;
    const AUDIENCE = String(config.get('JWT_AUDIENCE') ?? '').trim() || undefined;
    const SECRET = String(config.get('JWT_SECRET') ?? '').trim();

    const opts: any = {
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: SECRET,         // 필수
      ignoreExpiration: false,
      // 아래 두 개는 값이 있을 때만 넘김
      ...(ISSUER ? { issuer: ISSUER } : {}),
      ...(AUDIENCE ? { audience: AUDIENCE } : {}),
    };

    super(opts);
  }
  
  async validate(payload: JwtPayload): Promise<SafeUser> {
    if (!payload?.sub) {
      throw new UnauthorizedException('Invalid token');
    }

    // (옵션) 이메일 기반 조회가 더 정확/빠르면 먼저 시도
    if (payload.email && this.users.findByEmail) {
      const byEmail = await this.users.findByEmail(payload.email);
      if (byEmail) {
        return {
          id: String(byEmail.id),
          email: byEmail.email,
          role: byEmail.role ?? 'USER',
          name: byEmail.name,
        };
      }
    }

    // ID 기반 조회 (숫자/UUID 모두 대응)
    let byId: any = null;
    const idNum = Number(payload.sub);

    if (Number.isFinite(idNum) && (this.users as any).findOne) {
      // findOne(number) 시그니처가 있는 경우
      byId = await (this.users as any).findOne(idNum);
    }

    if (!byId && (this.users as any).findOneByUuid) {
      byId = await (this.users as any).findOneByUuid(payload.sub);
    }

    // 최후: findByEmail가 있었지만 이메일이 토큰에 없었던 경우 대비
    if (!byId && (this.users as any).findByEmail && payload.email) {
      byId = await (this.users as any).findByEmail(payload.email);
    }

    if (!byId) {
      throw new UnauthorizedException('User not found');
    }

    return {
      id: String(byId.id),
      email: byId.email,
      role: byId.role ?? 'USER',
      name: byId.name,
    };
  }
}
