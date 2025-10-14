// src/modules/auth/auth.module.ts
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
    MailerModule,
  ],
  controllers: [AuthController, EmailVerificationController],
  providers: [AuthService, JwtStrategy, EmailVerificationService],
  exports: [JwtModule, PassportModule, EmailVerificationService],
})
export class AuthModule {}
