// src/modules/auth/jwt-refresh.strategy.ts
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

export type RefreshPayload = { sub: string; email?: string; tokenId?: string };

@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(Strategy, 'jwt-refresh') {
  constructor(private readonly cfg: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      // ✅ 리프레시 토큰용 시크릿
      secretOrKey: cfg.get<string>('JWT_REFRESH_SECRET', 'refresh_secret_change_me'),
      ignoreExpiration: false,
      issuer: cfg.get<string>('JWT_ISSUER', 'kumeong-api'),
      audience: cfg.get<string>('JWT_AUDIENCE', 'kumeong-web'),
    });
  }

  async validate(payload: RefreshPayload) {
    // payload.sub = 사용자 ID
    return {
      id: payload.sub,
      email: payload.email,
      tokenId: payload.tokenId,
    };
  }
}
