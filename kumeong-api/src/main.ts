import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { SuccessResponseInterceptor } from './common/interceptors/success-response.interceptor';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';

function sanitizePrefix(p?: string) {
  const v = (p ?? 'api').trim();
  return v.replace(/^\/+|\/+$/g, ''); // 앞/뒤 슬래시 제거 -> 'api' 형태로 고정
}

function parseCorsOrigin(cfg: ConfigService) {
  const raw = (cfg.get<string>('CORS_ORIGIN') ?? '').trim();

  // 미설정: 개발 기본값 (localhost/127.0.0.1, 포트 가변 허용)
  if (!raw) {
    return [/^http:\/\/localhost(?::\d+)?$/, /^http:\/\/127\.0\.0\.1(?::\d+)?$/];
  }

  // '*'이면 모든 출처 허용(개발 편의). 이때 credentials는 false로 둬야 함.
  if (raw === '*') return true;

  // 콤마 구분 목록 + 정규식 표기(/.../) 지원
  return raw.split(',')
    .map(s => s.trim())
    .filter(Boolean)
    .map(s => (s.startsWith('/') && s.endsWith('/')) ? new RegExp(s.slice(1, -1)) : s);
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const cfg = app.get(ConfigService);

  // ========================
  // 1) CORS
  // ========================
  const originConf = parseCorsOrigin(cfg);
  const useCredentials = originConf !== true; // origin === true('* 반사')면 credentials 금지

  app.enableCors({
    origin: originConf,
    credentials: useCredentials,
    methods: ['GET','HEAD','PUT','PATCH','POST','DELETE','OPTIONS'],
    allowedHeaders: ['Content-Type','Authorization','X-Requested-With','Accept'],
    optionsSuccessStatus: 204,
  });

  // ========================
  // 2) Prefix & Versioning
  // ========================
  const apiPrefix = sanitizePrefix(cfg.get<string>('API_PREFIX'));
  const apiVersion = (cfg.get<string>('API_VERSION') ?? '1').trim();
  app.setGlobalPrefix(apiPrefix); // '/api'가 아니라 'api' 형태만 넣기
  app.enableVersioning({ type: VersioningType.URI, defaultVersion: apiVersion });

  // ========================
  // 3) ValidationPipe
  // ========================
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    transform: true,
    transformOptions: { enableImplicitConversion: true },
    forbidUnknownValues: false,
  }));

  // ========================
  // 4) Global Interceptor & Filter
  // ========================
  app.useGlobalInterceptors(new SuccessResponseInterceptor());
  app.useGlobalFilters(new GlobalExceptionFilter());

  // ========================
  // 5) Swagger
  // ========================
  const swaggerConfig = new DocumentBuilder()
    .setTitle('KU멍가게 API')
    .setDescription('캠퍼스 중고거래/배달(KU대리) 백엔드 v1')
    .setVersion('1.0.0')
    .addBearerAuth({
      type: 'http',
      scheme: 'bearer',
      bearerFormat: 'JWT',
      in: 'header',
      name: 'Authorization',
      description: 'JWT access token',
    }, 'bearer')
    .build();

  const swaggerDoc = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup(`/${apiPrefix}/docs`, app, swaggerDoc, {
    swaggerOptions: { persistAuthorization: true },
    customSiteTitle: 'KU멍가게 API Docs',
  });

  // ========================
  // 6) Listen
  // ========================
  const port = Number(cfg.get<string>('PORT') ?? 3000);
  await app.listen(port);

  const baseUrl = await app.getUrl();
  console.log(`🚀 ${baseUrl}/${apiPrefix}/v${apiVersion}`);
  console.log(`📚 Swagger: ${baseUrl}/${apiPrefix}/docs`);
  console.log(`🔓 CORS origin:`, originConf);
  console.log(`🔒 CORS credentials:`, useCredentials);
}

bootstrap().catch((err) => {
  console.error(err);
  process.exit(1);
});
