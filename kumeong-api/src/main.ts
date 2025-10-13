// C:\Users\82105\KU-meong Store\kumeong-api\src\main.ts
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe, VersioningType, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { SuccessResponseInterceptor } from './common/interceptors/success-response.interceptor';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { normalizeId } from './common/utils/ids';
import { DataSource } from 'typeorm';

/** prefix 문자열에서 /를 정리 */
function sanitizePrefix(p?: string) {
  const v = (p ?? 'api').trim();
  return v.replace(/^\/+|\/+$/g, '');
}

/** .env의 CORS_ORIGIN 파싱 */
function parseCorsOrigin(cfg: ConfigService) {
  const raw = (cfg.get<string>('CORS_ORIGIN') ?? '').trim();
  if (!raw) {
    return [/^http:\/\/localhost(?::\d+)?$/, /^http:\/\/127\.0\.0\.1(?::\d+)?$/];
  }
  if (raw === '*') return true;
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
    .map((s) => (s.startsWith('/') && s.endsWith('/') ? new RegExp(s.slice(1, -1)) : s));
}

/** 숫자 ID → UUID 문자열 변환 유틸 */
function toUuidFromNumeric(n: string): string {
  const digits = n.replace(/\D/g, '').slice(0, 12); // 12자리까지만 사용
  return `00000000-0000-0000-0000-${digits.padStart(12, '0')}`;
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const cfg = app.get(ConfigService);

  // ✅ 요청 전처리 미들웨어 (X-User-Id 숫자→UUID, UUID면 정규화)
  app.use((req, _res, next) => {
    const raw = req.headers['x-user-id'];
    if (typeof raw === 'string') {
      const normalized = /^\d+$/.test(raw) ? toUuidFromNumeric(raw) : raw;
      req.headers['x-user-id'] = normalizeId(normalized);
    }
    next();
  });

  // ✅ CORS 설정
  const originConf = parseCorsOrigin(cfg);
  app.enableCors({
    origin: originConf,
    credentials: true,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'X-User-Id', 'X-API-Version'],
    exposedHeaders: ['Content-Length'],
  });

  // ✅ API Prefix & Versioning — URI 방식 (/api/v1/*)
  const apiPrefix = sanitizePrefix(cfg.get<string>('API_PREFIX'));
  const apiVersion = (cfg.get<string>('API_VERSION') ?? '1').trim();

  app.setGlobalPrefix(apiPrefix);

  app.enableVersioning({
    type: VersioningType.URI,      // /api/v1/*
    defaultVersion: apiVersion,
  });

  // 🔁 호환 레이어: /api/* 로 오는 요청은 자동으로 /api/v{apiVersion}/* 로 승격
  // (프런트 전환 완료 후 제거 가능)
  app.use(`/${apiPrefix}`, (req, _res, next) => {
    // 이 미들웨어는 '/api'에 마운트되어 있으므로 req.url은 '/v1/...' 또는 '/friends' 형태
    if (!req.url.startsWith('/v')) {
      req.url = `/v${apiVersion}${req.url}`; // '/friends' -> '/v1/friends'
    }
    next();
  });

  // ✅ 글로벌 파이프/인터셉터/필터
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.useGlobalInterceptors(new SuccessResponseInterceptor());
  app.useGlobalFilters(new GlobalExceptionFilter());

  // ✅ Swagger 세팅 (/api/docs, 경로는 /api/v1/* 로 표시)
  const swaggerConfig = new DocumentBuilder()
    .setTitle('KU멍가게 API')
    .setDescription('캠퍼스 중고거래/배달(KU대리) 백엔드 v1')
    .setVersion('1.0.0')
    .addServer('/api/v1') // Swagger에서 basePath 설정
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'bearer')
    .build();

  // Swagger 문서 생성
  const swaggerDoc = SwaggerModule.createDocument(app, swaggerConfig, {
    operationIdFactory: (_controllerKey, methodKey) => methodKey,
  });

  // Swagger UI 설정
  SwaggerModule.setup(`/${apiPrefix}/docs`, app, swaggerDoc, {
    swaggerOptions: { docExpansion: 'none' },
  });


  // ✅ 부팅 시 DB/뷰 체크 로그
  const ds = app.get(DataSource);
  try {
    const [dbRow] = await ds.query('SELECT DATABASE() AS db');
    const currentDb = dbRow?.db ?? '(unknown)';
    const [viewRow] = await ds.query(
      `
      SELECT
        SUM(CASE WHEN table_name='vwfriendsforuser' THEN 1 ELSE 0 END) AS has_vwfriendsforuser,
        SUM(CASE WHEN table_name='vw_friends_for_user' THEN 1 ELSE 0 END) AS has_vw_friends_for_user,
        SUM(CASE WHEN table_name='vw_conversations_for_user' THEN 1 ELSE 0 END) AS has_vw_conversations_for_user
      FROM information_schema.VIEWS
      WHERE table_schema = ?
      `,
      [currentDb],
    );

    Logger.log(`[DB] connected to: ${currentDb}`);
    Logger.log(
      `[DB] views — vwfriendsforuser: ${viewRow?.has_vwfriendsforuser ? 'OK' : 'MISSING'}, ` +
        `vw_friends_for_user: ${viewRow?.has_vw_friends_for_user ? 'OK' : 'MISSING'}, ` +
        `vw_conversations_for_user: ${viewRow?.has_vw_conversations_for_user ? 'OK' : 'MISSING'}`,
    );
  } catch (e) {
    Logger.error(`[DB] startup check failed: ${(e as Error).message}`);
  }

  // ✅ 서버 시작
  const port = Number(cfg.get<string>('PORT') ?? 3000);
  await app.listen(port, '0.0.0.0');
  Logger.log(`🚀 Server running at http://localhost:${port}/${apiPrefix}/v${apiVersion}`);
  Logger.log(`   Swagger:        http://localhost:${port}/${apiPrefix}/docs`);
}

bootstrap().catch((e) => {
  Logger.error(e);
  process.exit(1);
});
