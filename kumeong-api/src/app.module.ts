// C:\Users\82105\KU-meong Store\kumeong-api\src\app.module.ts
import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DataSourceOptions } from 'typeorm';
import { MailerModule } from '@nestjs-modules/mailer';

import dataSource from './typeorm.config';
import { envValidationSchema } from './core/config/env.validation';

import { UsersModule } from './modules/users/users.module';
import { AuthModule } from './modules/auth/auth.module';
import { ProductsModule } from './modules/products/products.module';

import { UniversityVerificationModule } from './features/university/university-verification.module';
import { FriendsModule } from './features/friends/friends.module';
import { ChatsModule } from './features/chats/chats.module';

// ✅ 추가: X-User-Id 보정/자동생성 미들웨어
import { EnsureUserMiddleware } from './common/middleware/ensure-user.middleware';

@Module({
  imports: [
    // ===== Config =====
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      expandVariables: true,
      validationSchema: envValidationSchema,
      envFilePath: [
        `.env.${process.env.NODE_ENV}.local`,
        `.env.${process.env.NODE_ENV}`,
        '.env.local',
        '.env',
      ],
    }),

    // ===== DB =====
    TypeOrmModule.forRoot({
      ...(dataSource.options as DataSourceOptions),
      autoLoadEntities: true, // ✅ feature 모듈의 엔티티 자동 인식
      synchronize: false,
      dropSchema: false,
    }),

    // ===== Mailer (ENV: MAIL_*) =====
    MailerModule.forRoot({
      transport: {
        host: process.env.MAIL_HOST,
        port: Number(process.env.MAIL_PORT ?? 1025),
        secure: process.env.MAIL_SECURE === 'true',
        auth:
          process.env.MAIL_USER && process.env.MAIL_PASS
            ? { user: process.env.MAIL_USER, pass: process.env.MAIL_PASS }
            : undefined,
        connectionTimeout: 5000,
        greetingTimeout: 5000,
      },
      defaults: {
        from: process.env.MAIL_FROM ?? '"KU멍가게" <no-reply@kumeong.local>',
      },
    }),

    // ===== Feature Modules =====
    UsersModule,
    AuthModule,
    ProductsModule,
    UniversityVerificationModule,
    FriendsModule,
    ChatsModule,
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    // ✅ 전역 적용: 헤더에 X-User-Id 없거나 숫자면 UUID로 보정
    consumer.apply(EnsureUserMiddleware).forRoutes('*');
  }
}
