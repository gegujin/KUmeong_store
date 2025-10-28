// src/modules/auth/strategies/jwt.strategy.ts
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(private readonly config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_ACCESS_SECRET'),  // ✅ 통일
      issuer: config.get<string>('JWT_ISSUER') || undefined, // ✅ (발급에 넣었으면 함께)
      audience: config.get<string>('JWT_AUDIENCE') || undefined, // ✅ (발급에 넣었으면 함께)
    });
  }

  async validate(payload: any) {
    // 둘 다 채워서 하위 코드 호환성 확보
    return {
      id: payload.sub,         // ✅ favorites 등에서 기대하는 값
      sub: payload.sub,        // ✅ 기존 사용하는 코드도 보호
      email: payload.email,
      role: payload.role,
      // 필요하면 iss/aud 등도 그대로 실어도 됨
    };
  }
}
