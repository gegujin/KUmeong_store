// src/app.module.ts
import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MailerModule } from '@nestjs-modules/mailer';

import { envValidationSchema } from './core/config/env.validation';
import { mailConfigFactory } from './core/config/mail.config';

import { UsersModule } from './modules/users/users.module';
import { AuthModule } from './modules/auth/auth.module';
import { ProductsModule } from './modules/products/products.module';
import { UniversityVerificationModule } from './features/university/university-verification.module';
import { FriendsModule } from './features/friends/friends.module';
import { ChatsModule } from './features/chats/chats.module';
import { SystemModule } from './features/system/system.module';
import { FavoritesModule } from './modules/favorites/favorites.module';
import { DeliveryModule } from './modules/delivery/delivery.module';

import { EnsureUserMiddleware } from './common/middleware/ensure-user.middleware';

@Module({
  imports: [
    // ===================================
    // Global Config (K3s/Docker friendly)
    // ===================================
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      expandVariables: true,
      validationSchema: envValidationSchema,
      // ❗ K3s/Docker는 envFilePath 사용하면 안됨
      //    → 이미 config.module.ts에서 env 처리
      //    → 충돌 예방 위해 완전히 제거
    }),

    // ===================================
    // TypeORM
    // ===================================
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => {
        const pw =
          (cfg.get<string>('DB_PASSWORD') ??
            cfg.get<string>('DB_PASS') ??
            '')!.trim();

        return {
          type: 'mysql' as const,
          host: cfg.get<string>('DB_HOST', '127.0.0.1'),
          port: Number(cfg.get<string>('DB_PORT', '3306')),
          username:
            cfg.get<string>('DB_USERNAME') ??
            cfg.get<string>('DB_USER', 'root'),
          password: pw,
          database:
            cfg.get<string>('DB_DATABASE') ??
            cfg.get<string>('DB_NAME', 'kumeong_store'),
          charset: 'utf8mb4',
          autoLoadEntities: true,
          synchronize: false,
        };
      },
    }),

    // ===================================
    // Mail
    // ===================================
    MailerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => mailConfigFactory(cfg),
    }),

    // ===================================
    // Feature Modules
    // ===================================
    UsersModule,
    AuthModule,
    ProductsModule,
    UniversityVerificationModule,
    FriendsModule,
    ChatsModule,
    SystemModule,
    FavoritesModule,
    DeliveryModule,
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(EnsureUserMiddleware).forRoutes('*');
  }
}
