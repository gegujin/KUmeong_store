// src/app.module.ts
import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DataSourceOptions } from 'typeorm';
import { MailerModule } from '@nestjs-modules/mailer';

import dataSource from './typeorm.config';
import { envValidationSchema } from './core/config/env.validation';
import { mailConfigFactory } from './core/config/mail.config';

import { UsersModule } from './modules/users/users.module';
import { AuthModule } from './modules/auth/auth.module';
import { ProductsModule } from './modules/products/products.module';

import { UniversityVerificationModule } from './features/university/university-verification.module';
import { FriendsModule } from './features/friends/friends.module';
import { ChatsModule } from './features/chats/chats.module';
import { SystemModule } from './features/system/system.module';
import { ProductImage } from '../src/modules/products/entities/product-image.entity';

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
      autoLoadEntities: true,
      synchronize: false,
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
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(EnsureUserMiddleware).forRoutes('*');
  }
}
