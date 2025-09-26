// src/core/config/env.validation.ts
import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'test', 'production').default('development'),
  PORT: Joi.number().default(3000),
  API_PREFIX: Joi.string().default('/api'),
  API_VERSION: Joi.string().default('1'),
  CORS_ORIGIN: Joi.string().default('http://localhost:5173,http://localhost:3000'),

  // Auth
  JWT_SECRET: Joi.string().required(),
  JWT_EXPIRES: Joi.string().default('7d'),
  BCRYPT_SALT_ROUNDS: Joi.number().default(10),

  // DB 스위치
  DB_KIND: Joi.string().valid('mysql', 'sqlite').default('mysql'),
  DB_SYNC: Joi.string().valid('true', 'false').default('false'),

  // SQLite 전용
  DB_SQLITE_PATH: Joi.when('DB_KIND', {
    is: 'sqlite',
    then: Joi.string().required(),
    otherwise: Joi.string().optional(),
  }),

  // MySQL 전용 (sqlite일 땐 optional)
  DB_HOST: Joi.when('DB_KIND', { is: 'mysql', then: Joi.string().required(), otherwise: Joi.string().optional() }),
  DB_PORT: Joi.when('DB_KIND', { is: 'mysql', then: Joi.number().default(3306), otherwise: Joi.number().optional() }),
  DB_USERNAME: Joi.when('DB_KIND', { is: 'mysql', then: Joi.string().optional(), otherwise: Joi.string().optional() }),
  DB_PASSWORD: Joi.when('DB_KIND', { is: 'mysql', then: Joi.string().allow('').optional(), otherwise: Joi.string().optional() }),
  DB_DATABASE: Joi.when('DB_KIND', { is: 'mysql', then: Joi.string().optional(), otherwise: Joi.string().optional() }),

  // 레거시 호환(있어도 되고 없어도 됨)
  DB_USER: Joi.any().optional(),
  DB_PASS: Joi.any().optional(),

  EMAIL_CODE_TTL_SEC: Joi.number().default(300),
  EMAIL_COOLDOWN_SEC: Joi.number().default(60),
  EMAIL_MAX_ATTEMPTS: Joi.number().default(5),
  EMAIL_CODE_LENGTH: Joi.number().default(6),
});
