// C:\Users\82105\KU-meong Store\kumeong-api\src\typeorm.config.ts

import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as path from 'path';

/**
 * 📌 중요
 * K3s/Docker/Production 환경에서는 ConfigModule이 이미 ENV를 읽고 있기 때문에
 * dotenv(config) 를 이 파일에서 다시 호출하면 충돌/오염/중복 로딩 문제가 발생한다.
 *
 * 따라서 이 파일에서는 절대로 dotenv를 호출하지 않는다.
 * process.env 값만 그대로 사용한다.
 */

// ─────────────────────────────────────────────────────────
// 안전한 ENV 값 파싱
// ─────────────────────────────────────────────────────────
const isLogging = process.env.DB_LOGGING === 'true';

// 키 통합 처리 (legacy + new 공통 지원)
const host = process.env.DB_HOST ?? '127.0.0.1';
const port = Number(process.env.DB_PORT ?? 3306);
const username = process.env.DB_USERNAME ?? process.env.DB_USER ?? 'root';
const password = String(process.env.DB_PASSWORD ?? process.env.DB_PASS ?? '');
const database = process.env.DB_DATABASE ?? process.env.DB_NAME ?? 'kumeong_store';

// ─────────────────────────────────────────────────────────
// TypeORM DataSource 정의
// ─────────────────────────────────────────────────────────
const dataSource = new DataSource({
  type: 'mysql',
  host,
  port,
  username,
  password,
  database,

  // Entity 및 Migration 경로
  entities: [path.join(__dirname, '/**/*.entity{.ts,.js}')],
  migrations: [path.join(__dirname, '/migrations/*{.ts,.js}')],

  // 절대 production에서는 sync 사용 금지
  synchronize: false,

  /**
   * CLI에서만 migration:run을 실행하도록 설정
   * AppModule 실행 시 자동 실행 방지
   */
  migrationsRun: false,

  logging: isLogging ? ['query', 'error'] : false,
});

// 🚫 주의: 여기서 initialize() 호출하거나 console.log() 찍지 말 것
// (Nest 런타임/CLI 구동 순서에 혼선 생김)

export default dataSource;
