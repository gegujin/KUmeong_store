import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';

dotenv.config({ path: process.env.NODE_ENV ? `.env.${process.env.NODE_ENV}` : '.env' });

const host = process.env.DB_HOST ?? '127.0.0.1';
const port = Number(process.env.DB_PORT ?? 3306);
const username = process.env.DB_USERNAME ?? process.env.DB_USER ?? 'root';
const password = process.env.DB_PASSWORD ?? process.env.DB_PASS ?? '';
// ⚠️ 당신의 스키마명은 kumeong_store 이므로 .env에서 DB_DATABASE=kumeong_store 로 맞추세요.
const database = process.env.DB_DATABASE ?? process.env.DB_NAME ?? 'kumeong_store';

export const AppDataSource = new DataSource({
  type: 'mysql',
  host,
  port,
  username,
  password,
  database,
  charset: 'utf8mb4',
  entities: [__dirname + '/../modules/**/*.entity.{ts,js}'],
  migrations: [__dirname + '/migrations/*.{ts,js}'],

  // 절대 건드리지 않게!
  synchronize: false,
  migrationsRun: true,   // ⬅️ 서버 기동 시 마이그레이션만 자동 적용
  logging: false,        // 필요하면 ['error','warn','query'] 로
});

export default AppDataSource;
