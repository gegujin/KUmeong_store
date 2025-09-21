import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MailerModule } from '@nestjs-modules/mailer';

import { UsersModule } from '../users/users.module';
import { User } from '../users/entities/user.entity';

import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './jwt.strategy';

import { EmailVerification } from './entities/email-verification.entity';
import { EmailVerificationService } from './services/email-verification.service';
import { EmailVerificationController } from './controllers/email-verification.controller';

@Module({
  imports: [
    UsersModule,
    ConfigModule,
    PassportModule.register({ defaultStrategy: 'jwt', session: false }),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        secret: cfg.getOrThrow<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: cfg.get<string>('JWT_EXPIRES', '7d'),
          ...(cfg.get('JWT_ISSUER') ? { issuer: cfg.get('JWT_ISSUER') } : {}),
          ...(cfg.get('JWT_AUDIENCE') ? { audience: cfg.get('JWT_AUDIENCE') } : {}),
        },
      }),
    }),

    TypeOrmModule.forFeature([EmailVerification, User]),
    MailerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => {
        const isProd = cfg.get('NODE_ENV') === 'production';

        // ── 안전 파서
        const toBool = (v: unknown, def = false): boolean => {
          if (typeof v === 'boolean') return v;
          if (typeof v === 'number') return v !== 0;
          if (typeof v === 'string') {
            const s = v.trim().toLowerCase();
            return s === 'true' || s === '1' || s === 'yes' || s === 'on';
          }
          return def;
        };
        const toInt = (v: unknown, def: number): number => {
          const n = Number(v);
          return Number.isFinite(n) ? n : def;
        };

        // ── 환경값 파싱
        const host = cfg.get<string>('SMTP_HOST') ?? '';
        const secure = toBool(cfg.get<unknown>('SMTP_SECURE'), false);
        const port = toInt(cfg.get<unknown>('SMTP_PORT'), secure ? 465 : 587);
        const user = cfg.get<string>('SMTP_USER') ?? '';
        const pass = cfg.get<string>('SMTP_PASS') ?? '';
        const from = cfg.get<string>('MAIL_FROM') ?? 'no-reply@example.com';

        // 개발용 로그
        if (!isProd) {
          // eslint-disable-next-line no-console
          console.log('[MAILER] transport', { host, port, secure, user });
          // eslint-disable-next-line no-console
          console.log('[MAILER] defaults', { from });
        }

        if (!host || !user || !pass) {
          // eslint-disable-next-line no-console
          console.warn('[MAILER] WARN: SMTP_HOST/SMTP_USER/SMTP_PASS 중 일부가 비어 있습니다.');
        }

        const userDomain = user.includes('@') ? user.split('@')[1] : '';
        const fromAddrMatch = from.match(/<([^>]+)>/);
        const fromAddr = fromAddrMatch ? fromAddrMatch[1] : from;
        const fromDomain = fromAddr.includes('@') ? fromAddr.split('@')[1] : '';
        if (!isProd && userDomain && fromDomain && userDomain !== fromDomain) {
          // eslint-disable-next-line no-console
          console.warn(`[MAILER] WARN: MAIL_FROM(${fromAddr}) 도메인 ≠ SMTP_USER(${user}) 도메인`);
        }

        const transport: any = {
          host,
          port,
          secure,
          auth: { user, pass },
          ...(isProd ? {} : { logger: true, debug: true }),
        };

        return {
          transport,
          defaults: { from },
        };
      },
    }),
  ],
  controllers: [AuthController, EmailVerificationController],
  providers: [AuthService, JwtStrategy, EmailVerificationService],
  exports: [JwtModule, PassportModule, EmailVerificationService],
})
export class AuthModule {}
