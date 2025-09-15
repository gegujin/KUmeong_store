// src/main.ts
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { SuccessResponseInterceptor } from './common/interceptors/success-response.interceptor';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const cfg = app.get(ConfigService);

  // ========================
  // 1️⃣ CORS 설정
  // ========================
  const corsOrigin = cfg.get<string>('CORS_ORIGIN');
  const allowedOrigins = corsOrigin
    ? corsOrigin.split(',').map((o) => o.trim())
    : [
        'http://localhost:54350', // Flutter 웹 기본 포트
        'http://127.0.0.1:54350',
        'http://localhost:57498', // 브라우저에서 확인된 포트
        'http://127.0.0.1:57498',
      ];

  app.enableCors({
    origin: allowedOrigins,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
    preflightContinue: false,
    optionsSuccessStatus: 200,
  });


  // ========================
  // 2️⃣ Prefix & Versioning
  // ========================
  const apiPrefix = cfg.get<string>('API_PREFIX') ?? '/api';
  const apiVersion = cfg.get<string>('API_VERSION') ?? '1';
  app.setGlobalPrefix(apiPrefix);
  app.enableVersioning({ type: VersioningType.URI, defaultVersion: apiVersion });

  // ========================
  // 3️⃣ ValidationPipe
  // ========================
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
      forbidUnknownValues: false,
    }),
  );

  // ========================
  // 4️⃣ Global Interceptor & Filter
  // ========================
  app.useGlobalInterceptors(new SuccessResponseInterceptor());
  app.useGlobalFilters(new GlobalExceptionFilter());

  // ========================
  // 5️⃣ Swagger 설정
  // ========================
  const swaggerConfig = new DocumentBuilder()
    .setTitle('KU멍가게 API')
    .setDescription('캠퍼스 중고거래/배달(KU대리) 백엔드 v1')
    .setVersion('1.0.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        in: 'header',
        name: 'Authorization',
        description: 'JWT access token',
      },
      'bearer',
    )
    .build();

  const swaggerDoc = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup(`${apiPrefix}/docs`, app, swaggerDoc, {
    swaggerOptions: { persistAuthorization: true },
    customSiteTitle: 'KU멍가게 API Docs',
  });

  // ========================
  // 6️⃣ 서버 Listen
  // ========================
  const port = Number(cfg.get<string>('PORT') ?? 3000);
  await app.listen(port);

  const baseUrl = await app.getUrl();
  console.log(`🚀 ${baseUrl}${apiPrefix}/v${apiVersion}`);
  console.log(`📚 Swagger: ${baseUrl}${apiPrefix}/docs`);
}

bootstrap().catch((err) => {
  console.error(err);
  process.exit(1);
});
