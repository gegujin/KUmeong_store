import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config();

const isLogging = process.env.DB_LOGGING === 'true';

const host = process.env.DB_HOST ?? '127.0.0.1';
const port = Number(process.env.DB_PORT ?? 3306);
const username = process.env.DB_USERNAME ?? process.env.DB_USER ?? 'root';
const password = String(process.env.DB_PASSWORD ?? process.env.DB_PASS ?? '');
const database = process.env.DB_DATABASE ?? process.env.DB_NAME ?? 'kumeong_store';

const dataSource = new DataSource({
  type: 'mysql',
  host,
  port,
  username,
  password,
  database,

  entities: [
  path.join(__dirname, '../../**/*.entity.js'),
],
migrations: [
  path.join(__dirname, '../../migrations/*.js'),
],


  synchronize: false,
  migrationsRun: false,
  logging: isLogging ? ['query', 'error'] : false,
});

export default dataSource;
