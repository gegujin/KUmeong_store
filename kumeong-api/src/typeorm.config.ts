// C:\Users\82105\KU-meong Store\kumeong-api\src\typeorm.config.ts
// src/typeorm.config.ts
import 'reflect-metadata';
import { DataSource } from 'typeorm';
import { config } from 'dotenv';
import * as path from 'path';

// AppModule의 ConfigModule과 중복 로드되어도 무방 (CLI 대비)
config({ path: path.resolve(process.cwd(), process.env.NODE_ENV ? `.env.${process.env.NODE_ENV}` : '.env') });

const isLogging = process.env.DB_LOGGING === 'true';

// ── 키 통일 (새/레거시 모두 지원) ─────────────────────────────
const host = process.env.DB_HOST ?? '127.0.0.1';
const port = Number(process.env.DB_PORT ?? 3306);
const username = process.env.DB_USERNAME ?? process.env.DB_USER ?? 'root';
const password = String(process.env.DB_PASSWORD ?? process.env.DB_PASS ?? ''); // undefined 방지
const database = process.env.DB_DATABASE ?? process.env.DB_NAME ?? 'kumeong_store';

const dataSource = new DataSource({
  type: 'mysql',
  host,
  port,
  username,
  password,
  database,

  entities: [path.join(__dirname, '/**/*.entity{.ts,.js}')],
  migrations: [path.join(__dirname, '/migrations/*{.ts,.js}')],

  synchronize: false,
  migrationsRun: false, // CLI에서만 migrate:run 실행
  logging: isLogging ? ['query', 'error'] : false,
});

// ❌ 런타임 혼선 방지: 여기서 console.log/initialize 호출 금지
export default dataSource;


// import 'reflect-metadata';
// import { DataSource } from 'typeorm';
// import { config } from 'dotenv';
// import * as path from 'path';

// // .env 로드 (AppModule의 ConfigModule과 중복되어도 무방. CLI 실행 대비)
// config({ path: path.resolve(process.cwd(), '.env') });

// const isLogging = process.env.DB_LOGGING === 'true';

// const dataSource = new DataSource({
//   type: 'mysql',
//   host: process.env.DB_HOST || '127.0.0.1',
//   port: Number(process.env.DB_PORT) || 3306,
//   username: process.env.DB_USER || 'root',
//   password: process.env.DB_PASS || 'root',
//   database: process.env.DB_NAME || 'kumeong_store',

//   // 엔티티/마이그레이션 경로
//   entities: [path.join(__dirname, '/**/*.entity{.ts,.js}')],
//   migrations: [path.join(__dirname, '/migrations/*{.ts,.js}')],

//   // 절대 true 금지 (뷰/임시 오브젝트가 지워질 수 있음)
//   synchronize: false,

//   // 쿼리 로깅 (원하면 .env에서 DB_LOGGING=true)
//   logging: isLogging ? ['query', 'error'] : false,

//   // 필요시: 여러 문장 실행 스크립트 SOURCE용
//   // extra: { multipleStatements: true }, // MySQL2 드라이버 옵션
// });

// // 디버그용 연결 정보(민감정보 제외)
// console.log('[DB-CONNECT-INFO]', {
//   type: dataSource.options.type,
//   host: (dataSource.options as any).host,
//   port: (dataSource.options as any).port,
//   database: (dataSource.options as any).database,
//   driver: dataSource.driver.constructor.name,
// });

// export default dataSource; // ✅ 단일 export
