// src/core/database/database.module.ts
import { Global, Module } from '@nestjs/common';
import { TypeOrmModule, TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { SnakeNamingStrategy } from 'typeorm-naming-strategies';
import { MysqlConnectionOptions } from 'typeorm/driver/mysql/MysqlConnectionOptions';
import { SqliteConnectionOptions } from 'typeorm/driver/sqlite/SqliteConnectionOptions';

@Global()
@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService): TypeOrmModuleOptions => {
        const kind = (cfg.get<'mysql'|'sqlite'|'memory'>('DB_KIND') ?? 'sqlite').trim() as 'mysql'|'sqlite'|'memory';
        const isProd = process.env.NODE_ENV === 'production';

        // mutable 배열 유지
        const common = {
          autoLoadEntities: true,
          namingStrategy: new SnakeNamingStrategy(),
          synchronize: kind === 'mysql' ? false : true,
          migrationsRun: isProd,
          logging: !isProd,
          migrations: ['dist/migrations/*.js'] as (string | Function)[],
        };

        if (kind === 'mysql') {
          // 🔒 이중 소스 조회 + 기본값 강제
          const host =
            cfg.get<string>('DB_HOST') ?? process.env.DB_HOST ?? '127.0.0.1';
          const port =
            cfg.get<number>('DB_PORT') ?? Number(process.env.DB_PORT ?? 3306);
          const username =
            cfg.get<string>('DB_USERNAME')
              ?? process.env.DB_USERNAME
              ?? cfg.get<string>('DB_USER')
              ?? process.env.DB_USER
              ?? 'root';
          const passwordRaw =
            cfg.get<string>('DB_PASSWORD')
              ?? process.env.DB_PASSWORD
              ?? cfg.get<string>('DB_PASS')
              ?? process.env.DB_PASS
              ?? '';
          // ❗ mysql2가 undefined를 받으면 "using password: NO"가 뜬다.
          const password = String(passwordRaw); // 항상 문자열
          const database =
            cfg.get<string>('DB_DATABASE')
              ?? process.env.DB_DATABASE
              ?? cfg.get<string>('DB_NAME')
              ?? process.env.DB_NAME
              ?? 'kumeong_store';

          // 디버그: 패스워드 노출 금지(길이만)
          console.log('[DB-BOOT]', {
            kind: 'mysql',
            host,
            port,
            username,
            database,
            passwordLen: password.length,
            usingPasswordNoFlagShouldBeFalse: password !== undefined, // 항상 true여야 함
          });

          const opts: MysqlConnectionOptions = {
            type: 'mysql',
            host,
            port,
            username,
            password,     // ← 이제 절대 undefined 아님
            database,
            charset: 'utf8mb4',
            ...common,
          };
          return opts as TypeOrmModuleOptions;
        }

        if (kind === 'memory') {
          const opts: SqliteConnectionOptions = {
            type: 'sqlite',
            database: ':memory:',
            dropSchema: true,
            ...common,
          };
          return opts as TypeOrmModuleOptions;
        }

        const opts: SqliteConnectionOptions = {
          type: 'sqlite',
          database: cfg.get<string>('DB_SQLITE_PATH', 'data/kumeong.sqlite')!,
          ...common,
        };
        return opts as TypeOrmModuleOptions;
      },
    }),
  ],
  exports: [TypeOrmModule],
})
export class DatabaseModule {}
