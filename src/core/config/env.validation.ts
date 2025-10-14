// src/core/config/env.validation.ts
import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  // ───────── 기본 서버 설정 ─────────
  NODE_ENV: Joi.string()
    .valid('development', 'staging', 'test', 'production') // test 유지
    .default('development'),
  PORT: Joi.number().default(3000),
  API_PREFIX: Joi.string().default('/api'),
  API_VERSION: Joi.string().default('1'),

  // CORS_ORIGIN: 단일 정규식 또는 쉼표 리스트를 문자열로 허용
  // (실제 파싱은 앱 레벨에서 처리)
  CORS_ORIGIN: Joi.string().optional(),

  // ───────── 인증(JWT/Bcrypt) ─────────
  JWT_SECRET: Joi.string().required(),
  JWT_EXPIRES: Joi.string().default('7d'),
  BCRYPT_SALT_ROUNDS: Joi.number().default(10),

  // ───────── 메일 설정 (override → provider → 레거시) ─────────
  // 공통 From
  MAIL_FROM: Joi.string().optional(),
  UNIV_VERIFY_FROM: Joi.string().optional(),

  // 신규 override (있으면 최우선)
  MAIL_HOST: Joi.string().hostname().optional(),
  MAIL_PORT: Joi.number().integer().min(1).max(65535).optional(),
  MAIL_SECURE: Joi.boolean().optional(),
  MAIL_USER: Joi.string().allow('', null).optional(),
  MAIL_PASS: Joi.string().allow('', null).optional(),

  // provider 스위치
  MAIL_PROVIDER: Joi.string()
    .valid('auto', 'mailpit', 'mailtrap', 'smtp')
    .default('auto'),

  // 레거시 호환 (DEV/STAGE/PROD)
  // DEV (Mailpit)
  DEV_MAIL_HOST: Joi.string().optional(),
  DEV_MAIL_PORT: Joi.number().optional(),
  DEV_MAIL_SECURE: Joi.boolean().optional(),
  DEV_MAIL_USER: Joi.string().allow('', null).optional(),
  DEV_MAIL_PASS: Joi.string().allow('', null).optional(),

  // STAGE (Mailtrap)
  STAGE_MAIL_HOST: Joi.string().optional(),
  STAGE_MAIL_PORT: Joi.number().optional(),
  STAGE_MAIL_SECURE: Joi.boolean().optional(),
  STAGE_MAIL_USER: Joi.string().optional(),
  STAGE_MAIL_PASS: Joi.string().optional(),

  // PROD (실 SMTP)
  PROD_MAIL_HOST: Joi.string().optional(),
  PROD_MAIL_PORT: Joi.number().optional(),
  PROD_MAIL_SECURE: Joi.boolean().optional(),
  PROD_MAIL_USER: Joi.string().optional(),
  PROD_MAIL_PASS: Joi.string().optional(),

  // ───────── DB 설정 (MySQL / SQLite 공용) ─────────
  DB_KIND: Joi.string().valid('mysql', 'sqlite').default('mysql'),
  DB_SYNC: Joi.string().valid('true', 'false').default('false'), // 기존 방식 유지

  // MySQL 전용
  DB_HOST: Joi.when('DB_KIND', {
    is: 'mysql',
    then: Joi.string().required(),
    otherwise: Joi.string().optional(),
  }),
  DB_PORT: Joi.when('DB_KIND', {
    is: 'mysql',
    then: Joi.number().default(3306),
    otherwise: Joi.number().optional(),
  }),
  DB_USERNAME: Joi.when('DB_KIND', {
    is: 'mysql',
    then: Joi.string().optional(),
    otherwise: Joi.string().optional(),
  }),
  DB_PASSWORD: Joi.when('DB_KIND', {
    is: 'mysql',
    then: Joi.string().allow('').optional(),
    otherwise: Joi.string().optional(),
  }),
  DB_DATABASE: Joi.when('DB_KIND', {
    is: 'mysql',
    then: Joi.string().optional(),
    otherwise: Joi.string().optional(),
  }),

  // 레거시 호환
  DB_USER: Joi.any().optional(),
  DB_PASS: Joi.any().optional(),

  // ───────── 이메일 인증 제한 (학교인증 등) ─────────
  EMAIL_CODE_TTL_SEC: Joi.number().default(300),
  EMAIL_COOLDOWN_SEC: Joi.number().default(60),
  EMAIL_MAX_ATTEMPTS: Joi.number().default(5),
  EMAIL_CODE_LENGTH: Joi.number().default(6),

  // 선호 키 (UNIV_*) — 있으면 서비스 레이어에서 우선 사용
  UNIV_VERIFY_CODE_TTL_SEC: Joi.number().optional(),
  UNIV_VERIFY_COOLDOWN_SEC: Joi.number().optional(),

  // ───────── Redis (선택) ─────────
  REDIS_URL: Joi.string().allow('').default(''),
});
