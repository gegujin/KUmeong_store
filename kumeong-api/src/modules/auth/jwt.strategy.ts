import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../users/users.service';

export type JwtPayload = {
  sub: string | number;
  email?: string;
  role?: string;
  iat?: number;
  exp?: number;
};

export type SafeUser = {
  id: number;
  email: string;
  role?: string;
};

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    private readonly users: UsersService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: config.get<string>('JWT_SECRET'),
      ignoreExpiration: false,
    });
  }

  async validate(payload: JwtPayload): Promise<SafeUser> {
    if (!payload) {
      throw new UnauthorizedException('Invalid token');
    }

    // 1) 이메일 우선: 메모리 테스트 유저(student@kku.ac.kr) 포함 커버
    if (payload.email) {
      const byEmail = await this.users.findByEmail?.(payload.email);
      if (byEmail) {
        return {
          id: Number(byEmail.id),
          email: byEmail.email,
          role: byEmail.role ?? 'USER',
        };
      }
    }

    // 2) 폴백: DB id 조회
    const userId = Number(payload.sub);
    if (!Number.isFinite(userId)) {
      throw new UnauthorizedException('Invalid token subject');
    }
    const byId = await this.users.findOne?.(userId);
    if (!byId) {
      throw new UnauthorizedException('User not found');
    }

    return {
      id: Number(byId.id),
      email: byId.email,
      role: byId.role ?? 'USER',
    };
  }
}
