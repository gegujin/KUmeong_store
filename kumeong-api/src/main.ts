// src/main.ts
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { Logger, VersioningType } from '@nestjs/common';
import 'source-map-support/register';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { SuccessResponseInterceptor } from './common/interceptors/success-response.interceptor';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { DataSource } from 'typeorm';
import { join } from 'path';
import * as express from 'express';
import * as http from 'http';
import { WebSocketServer, WebSocket } from 'ws';
const methodOverride = require('method-override');

// ✅ 추가: 파일·라인 포함 검증용 전역 파이프/필터/인터셉터
import { createGlobalValidationPipe } from './common/pipes/global-validation.pipe';
import { ValidationErrorFilter } from './common/filters/validation-error.filter';
import { RouteContextInterceptor } from './common/interceptors/route-context.interceptor';
// (선택) 상세 HTTP 로깅이 필요하면 아래도 import 후 등록
// import { LoggingInterceptor } from './common/interceptors/logging.interceptor';

type Sub = { ws: WebSocket; roomId: string; userId?: string };

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log', 'debug', 'verbose'],
  });
  const cfg = app.get(ConfigService);

  // ===== Prefix & URI Versioning =====
  const apiPrefix = 'api'; // /api
  app.setGlobalPrefix(apiPrefix);
  app.enableVersioning({
    type: VersioningType.URI, // /v1/...
    defaultVersion: '1',
  });
  Logger.log(`[HTTP] prefix="/${apiPrefix}" (URI versioning /v1 enabled)`);

  // ===== 공통 미들웨어 =====
  app.enableCors({
    origin: true,
    credentials: true,
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'X-User-Id',
      'X-HTTP-Method-Override',
    ],
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  });

  // method-override (헤더 & 폼파라미터)
  app.use(methodOverride('X-HTTP-Method-Override'));
  app.use(methodOverride('_method'));

  app.use('/uploads', express.static(join(process.cwd(), 'uploads')));

  // ===== 전역 파이프/인터셉터/필터 (★ 핵심 변경 지점)
  app.useGlobalPipes(createGlobalValidationPipe());         // ← 기존 ValidationPipe 교체
  app.useGlobalInterceptors(
    new RouteContextInterceptor(),                         // ← 라우트/컨트롤러/핸들러 정보 주입
    // new LoggingInterceptor(),                           // ← (옵션) HTTP 상세 로깅
    new SuccessResponseInterceptor()
  );
  app.useGlobalFilters(
    new ValidationErrorFilter(),                            // ← DTO 검증 400을 파일/라인 포함해 변환
    new GlobalExceptionFilter()
  );

  // ===== Swagger =====
  const swaggerConfig = new DocumentBuilder()
    .setTitle('KU멍가게 API')
    .setDescription('캠퍼스 중고거래/배달(KU대리) 백엔드 v1')
    .setVersion('1.0.0')
    .addServer(`/api`) // base만 두면 /v1은 URI 버전닝으로 자동 부착
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'bearer')
    .build();
  const swaggerDoc = SwaggerModule.createDocument(app, swaggerConfig, {
    operationIdFactory: (_controllerKey, methodKey) => methodKey,
  });
  SwaggerModule.setup(`/${apiPrefix}/docs`, app, swaggerDoc, {
    swaggerOptions: { docExpansion: 'none' },
  });

  // ===== DB 체크 =====
  const ds = app.get(DataSource);
  try {
    const [dbRow] = await ds.query('SELECT DATABASE() AS db');
    const currentDb = dbRow?.db ?? '(unknown)';
    Logger.log(`[DB] connected to: ${currentDb}`);
  } catch (e) {
    Logger.error(`[DB] startup check failed: ${(e as Error).message}`);
  }

  // ✅ 외부 서버를 쓸 때는 반드시 init() 먼저!
  await app.init();

  // ===== HTTP + WS 같은 포트 =====
  const server = http.createServer(app.getHttpAdapter().getInstance());
  const wss = new WebSocketServer({ server, path: '/ws/realtime' });

  const rooms = new Map<string, Set<Sub>>();
  function joinRoom(sub: Sub) {
    const set = rooms.get(sub.roomId) ?? new Set<Sub>();
    set.add(sub);
    rooms.set(sub.roomId, set);
  }
  function leave(ws: WebSocket) {
    for (const set of rooms.values()) {
      for (const s of Array.from(set)) if (s.ws === ws) set.delete(s);
    }
  }

  wss.on('connection', (ws, req) => {
    try {
      const url = new URL(req.url ?? '', `http://${req.headers.host}`);
      const roomId = url.searchParams.get('room') ?? '';
      const userId = url.searchParams.get('me') ?? '';
      if (!roomId) {
        ws.close(1008, 'room query required');
        return;
      }
      const sub: Sub = { ws, roomId, userId: userId || undefined };
      joinRoom(sub);

      ws.on('message', (buf) => {
        try {
          const msg = JSON.parse(String(buf));
          if (msg?.type === 'ping') {
            ws.send(JSON.stringify({ type: 'pong', t: new Date().toISOString() }));
          }
        } catch { /* ignore */ }
      });
      ws.on('close', () => leave(ws));
      ws.on('error', () => leave(ws));
    } catch {
      ws.close(1011, 'bad request');
    }
  });

  (global as any).broadcastChatToRoom = (roomId: string, payload: any) => {
    const set = rooms.get(roomId);
    if (!set?.size) return;
    const frame = JSON.stringify({
      id: Date.now(),
      kind: 'chat.msg',
      roomId,
      refId: payload.id,
      userId: payload.senderId,
      payload: {
        seq: payload.seq,
        senderId: payload.senderId,
        type: 'TEXT',
        content: payload.text ?? '',
        createdAt: payload.timestamp,
      },
    });
    for (const s of set) if (s.ws.readyState === WebSocket.OPEN) s.ws.send(frame);
  };

  // ===== Route Dump (디버그)
  const httpAdapter: any = app.getHttpAdapter();
  const expressApp: any = httpAdapter.getInstance ? httpAdapter.getInstance() : httpAdapter;
  const stack: any[] = expressApp?._router?.stack ?? [];
  for (const layer of stack) {
    if (layer.route) {
      const p = layer.route.path;
      const ms = Object.keys(layer.route.methods).join(',').toUpperCase();
      Logger.log(`[ROUTE] ${ms} ${p}`);
    } else if (layer.name === 'router' && layer.handle?.stack) {
      for (const s of layer.handle.stack) {
        if (s.route) {
          const p = s.route.path;
          const ms = Object.keys(s.route.methods).join(',').toUpperCase();
          Logger.log(`[ROUTE] ${ms} ${p}`);
        }
      }
    }
  }

  // ===== Listen =====
  const port = Number(cfg.get<string>('PORT') ?? 3000);
  await new Promise<void>((resolve) => server.listen(port, '0.0.0.0', () => resolve()));

  Logger.log(`🚀 Server running at http://localhost:${port}/api/v1`);
  Logger.log(`📘 Swagger:        http://localhost:${port}/${apiPrefix}/docs`);
  Logger.log(`🔌 WS endpoint:    ws://localhost:${port}/ws/realtime?room=<roomId>&me=<uuid>`);
}

bootstrap().catch((e) => {
  Logger.error(e);
  process.exit(1);
});
