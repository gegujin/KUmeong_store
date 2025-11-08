// src/database/data-source.ts
import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';

// NODE_ENV 별 .env 로드 (CLI 실행 시 유용). Nest 런타임에선 ConfigModule이 따로 처리함.
dotenv.config({ path: process.env.NODE_ENV ? `.env.${process.env.NODE_ENV}` : '.env' });

// ── 키 통일 (새/레거시 모두 지원)
const host = process.env.DB_HOST ?? '127.0.0.1';
const port = Number(process.env.DB_PORT ?? 3306);
const username = process.env.DB_USERNAME ?? process.env.DB_USER ?? 'root';
const password = String(process.env.DB_PASSWORD ?? process.env.DB_PASS ?? '');
const database = process.env.DB_DATABASE ?? process.env.DB_NAME ?? 'kumeong_store';

/**
 * ⚠️ 주의
 * - 여기서는 "옵션"만 정의한다.
 * - Nest 애플리케이션 런타임 초기화는 AppModule의 `TypeOrmModule.forRoot(...)`가 수행한다.
 * - CLI(typeorm)에서는 이 객체를 -d 옵션으로 넘겨 사용한다.
 */
export const AppDataSource = new DataSource({
  type: 'mysql',
  host,
  port,
  username,
  password,
  database,
  charset: 'utf8mb4',

  // CLI/빌드 환경 모두 커버 (ts-node 실행/빌드 후 dist 실행)
  entities: [
    'src/**/*.entity.ts',
    'dist/**/*.entity.js',
  ],
  migrations: [
    'src/database/migrations/*.{ts,js}',
    'dist/database/migrations/*.{ts,js}',
  ],

  // 런타임 혼선 방지: CLI에서만 제어 (AppModule에서는 synchronize:false 고정)
  synchronize: false,
  migrationsRun: false,
  logging: false,
});

export default AppDataSource; // ← AppModule에서 options만 가져다 씀



// import 'reflect-metadata';
// import { DataSource } from 'typeorm';
// import * as dotenv from 'dotenv';

// dotenv.config({ path: process.env.NODE_ENV ? `.env.${process.env.NODE_ENV}` : '.env' });

// const host = process.env.DB_HOST ?? '127.0.0.1';
// const port = Number(process.env.DB_PORT ?? 3306);
// const username = process.env.DB_USERNAME ?? process.env.DB_USER ?? 'root';
// const password = process.env.DB_PASSWORD ?? process.env.DB_PASS ?? '';
// // ⚠️ 당신의 스키마명은 kumeong_store 이므로 .env에서 DB_DATABASE=kumeong_store 로 맞추세요.
// const database = process.env.DB_DATABASE ?? process.env.DB_NAME ?? 'kumeong_store';

// export const AppDataSource = new DataSource({
//   type: 'mysql',
//   host,
//   port,
//   username,
//   password,
//   database,
//   charset: 'utf8mb4',
//   entities: [__dirname + '/../modules/**/*.entity.{ts,js}'],
//   migrations: [__dirname + '/migrations/*.{ts,js}'],

//   // 절대 건드리지 않게!
//   synchronize: false,
//   migrationsRun: true,   // ⬅️ 서버 기동 시 마이그레이션만 자동 적용
//   logging: false,        // 필요하면 ['error','warn','query'] 로
// });

// export default AppDataSource;
