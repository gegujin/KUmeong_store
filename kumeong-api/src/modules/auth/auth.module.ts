// src/modules/auth/auth.module.ts
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MailerModule } from '@nestjs-modules/mailer';

import { UsersModule } from '../users/users.module';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './jwt.strategy';

import { EmailVerification } from './entities/email-verification.entity';
import { EmailVerificationService } from './services/email-verification.service';
import { EmailVerificationController } from './controllers/email-verification.controller';

@Module({
  imports: [
    // ─── Core Auth (JWT/Passport) ───
    UsersModule,                      // JwtStrategy가 UsersService 주입받음
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

    // ─── Email verification (DB + Mailer) ───
    TypeOrmModule.forFeature([EmailVerification]),
    MailerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        transport: {
          host: cfg.get<string>('SMTP_HOST'),
          port: Number(cfg.get('SMTP_PORT')),
          secure: cfg.get('SMTP_SECURE') === true || cfg.get('SMTP_SECURE') === 'true',
          auth: {
            user: cfg.get<string>('SMTP_USER'),
            pass: cfg.get<string>('SMTP_PASS'),
          },
        },
        defaults: {
          from: cfg.get<string>('MAIL_FROM') ?? 'no-reply@example.com',
        },
      }),
    }),
  ],
  controllers: [AuthController, EmailVerificationController],
  providers: [AuthService, JwtStrategy, EmailVerificationService],
  exports: [JwtModule, PassportModule, EmailVerificationService],
})
export class AuthModule {}