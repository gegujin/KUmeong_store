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

import { createGlobalValidationPipe } from './common/pipes/global-validation.pipe';
import { ValidationErrorFilter } from './common/filters/validation-error.filter';
import { RouteContextInterceptor } from './common/interceptors/route-context.interceptor';

type Sub = { ws: WebSocket; roomId: string; userId?: string };

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log', 'debug', 'verbose'],
  });
  const cfg = app.get(ConfigService);

  // ===== Prefix & URI Versioning =====
  const apiPrefix = 'api';
  app.setGlobalPrefix(apiPrefix);
  app.enableVersioning({
    type: VersioningType.URI,
    defaultVersion: '1',   // => /v1
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
  app.use(methodOverride('X-HTTP-Method-Override'));
  app.use(methodOverride('_method'));
  app.use('/uploads', express.static(join(process.cwd(), 'uploads')));

  // ===== 전역 파이프/인터셉터/필터 =====
  app.useGlobalPipes(createGlobalValidationPipe());
  app.useGlobalInterceptors(
    new RouteContextInterceptor(),
    new SuccessResponseInterceptor()
  );
  app.useGlobalFilters(
    new ValidationErrorFilter(),
    new GlobalExceptionFilter()
  );

  // ===== Swagger =====
  const swaggerConfig = new DocumentBuilder()
    .setTitle('KU멍가게 API')
    .setDescription('캠퍼스 중고거래/배달(KU대리) 백엔드 v1')
    .setVersion('1.0.0')
    .addServer(`/api/v1`) // 🔧 기존 '/api' → '/api/v1' 로 교체
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'bearer')
    .build();
  const swaggerDoc = SwaggerModule.createDocument(app, swaggerConfig, {
    operationIdFactory: (_c, m) => m,
  });
  SwaggerModule.setup(`/${apiPrefix}/docs`, app, swaggerDoc, {
    swaggerOptions: { docExpansion: 'none' },
  });

  // ===== DB 체크 =====
  const ds = app.get(DataSource);
  try {
    const [dbRow] = await ds.query('SELECT DATABASE() AS db');
    Logger.log(`[DB] connected to: ${dbRow?.db ?? '(unknown)'}`);
  } catch (e) {
    Logger.error(`[DB] startup check failed: ${(e as Error).message}`);
  }

  // Nest 내부 초기화
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

  // ===== Listen =====
  const port = Number(cfg.get<string>('PORT') ?? 3000);
  await new Promise<void>((resolve) => server.listen(port, '0.0.0.0', () => resolve()));

  const base = `http://localhost:${port}`;
  Logger.log(`🚀 Server running at ${base}/api/v1`);
  Logger.log(`📘 Swagger:        ${base}/${apiPrefix}/docs`);
  Logger.log(`🔌 WS endpoint:    ws://localhost:${port}/ws/realtime?room=<roomId>&me=<uuid>`);
}

bootstrap().catch((e) => {
  Logger.error(e);
  process.exit(1);
});
