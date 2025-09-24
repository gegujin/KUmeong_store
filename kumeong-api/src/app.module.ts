// src/app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { envValidationSchema } from './core/config/env.validation';

import { UsersModule } from './modules/users/users.module';
import { AuthModule } from './modules/auth/auth.module';
import { ProductsModule } from './modules/products/products.module';

// ⬇️ 대학 이메일 인증 모듈 추가
import { UniversityVerificationModule } from './features/university/university-verification.module';

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
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => {
        const kind = cfg.get<string>('DB_KIND') ?? 'mysql';
        const nodeEnv = cfg.get<string>('NODE_ENV') ?? 'development';
        const isProd = nodeEnv === 'production';

        // 공통 옵션
        const logging =
          (cfg.get<string>('DB_LOGGING') === 'true') || !isProd; // 개발 기본 on
        const synchronize =
          cfg.get<string>('DB_SYNC') === 'true' && !isProd;      // 프로덕션 보호
        const dropSchema =
          cfg.get<string>('DB_DROP_SCHEMA') === 'true' && !isProd;

        if (kind === 'sqlite') {
          return {
            type: 'sqlite' as const,
            database: cfg.get<string>('DB_SQLITE_PATH') ?? 'data/dev.sqlite',
            autoLoadEntities: true,
            synchronize,
            dropSchema,
            logging,
          };
        }

        // MySQL / MariaDB
        return {
          type: 'mysql' as const,
          host: cfg.get<string>('DB_HOST') ?? '127.0.0.1',
          port: Number(cfg.get<number>('DB_PORT') ?? 3306),
          username: cfg.get<string>('DB_USERNAME') ?? cfg.get<string>('DB_USER') ?? 'root',
          password: cfg.get<string>('DB_PASSWORD') ?? cfg.get<string>('DB_PASS') ?? '',
          database: cfg.get<string>('DB_DATABASE') ?? cfg.get<string>('DB_NAME') ?? 'app',
          autoLoadEntities: true,
          synchronize,
          dropSchema,
          logging,
          charset: cfg.get<string>('DB_CHARSET') ?? 'utf8mb4',
          timezone: cfg.get<string>('DB_TIMEZONE') ?? '+09:00', // KST
          // retryAttempts: 3,
          // retryDelay: 2000,
        };
      },
    }),

    // ===== Feature Modules =====
    UsersModule,
    AuthModule,
    ProductsModule,

    // 대학 이메일 인증 모듈 등록
    UniversityVerificationModule,
  ],
})
export class AppModule {}
