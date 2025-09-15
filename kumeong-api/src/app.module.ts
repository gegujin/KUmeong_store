// src/app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { envValidationSchema } from './core/config/env.validation';

import { UsersModule } from './modules/users/users.module';
import { AuthModule } from './modules/auth/auth.module';
import { ProductsModule } from './modules/products/products.module';

@Module({
  imports: [
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

    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => {
        const kind = cfg.get<string>('DB_KIND');
        if (kind === 'sqlite') {
          return {
            type: 'sqlite' as const,
            database: cfg.get<string>('DB_SQLITE_PATH'),
            autoLoadEntities: true,
            synchronize: cfg.get('DB_SYNC') === 'true',
          };
        }

        return {
          type: 'mysql' as const,
          host: cfg.get<string>('DB_HOST'),
          port: cfg.get<number>('DB_PORT'),
          username: cfg.get<string>('DB_USERNAME') ?? cfg.get<string>('DB_USER'),
          password: cfg.get<string>('DB_PASSWORD') ?? cfg.get<string>('DB_PASS'),
          database: cfg.get<string>('DB_DATABASE') ?? cfg.get<string>('DB_NAME'),
          autoLoadEntities: true,
          synchronize: true,   // 그냥 true로 바꿔도 됨
          dropSchema: true, 
          charset: 'utf8mb4',
        };
      },
    }),

    UsersModule,
    AuthModule,
    ProductsModule,
  ],
})
export class AppModule {}
