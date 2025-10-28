import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MailerModule } from '@nestjs-modules/mailer';
import { DataSourceOptions } from 'typeorm';

import dataSource from './database/data-source'; // ✅ 파일 경로 통일 (원래 './typeorm.config'였다면 교체)
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

    // ===== TypeORM =====
    TypeOrmModule.forRoot({
      ...(dataSource.options as DataSourceOptions),

      // ⛔️ 아래 옵션들은 data-source.ts와 충돌하니 절대 다시 켜지 않게 고정
      synchronize: false,     // ⬅️ 강제 OFF
      migrationsRun: true,    // ⬅️ 마이그레이션만 사용
      // namingStrategy: undefined, // SnakeNamingStrategy 쓰지 않음 (엔티티에서 name 매핑으로 처리)
      autoLoadEntities: true, // 엔티티 자동 로드(선호도에 따라 유지)
      dropSchema: false,
    }),

    // ===== Mailer =====
    MailerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => mailConfigFactory(cfg),
    }),

    // ===== Modules =====
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
