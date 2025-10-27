import {
  ArgumentsHost,
  BadRequestException,
  Catch,
  ExceptionFilter,
} from '@nestjs/common';
import type { Request, Response } from 'express';

function pickTopTsFrame(stack?: string): string | undefined {
  if (!stack) return;
  // 첫 번째 TS 프레임을 간단히 잡아온다 (예: src/path/file.ts:12:34)
  const lines = stack.split('\n').map((s) => s.trim());
  const hit = lines.find((l) => l.includes('.ts:'));
  return hit;
}

@Catch(BadRequestException)
export class ValidationErrorFilter implements ExceptionFilter {
  catch(exception: BadRequestException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest<Request>() as any;
    const res = ctx.getResponse<Response>();

    const payload = (exception.getResponse?.() as any) ?? {};
    const status = exception.getStatus?.() ?? 400;

    const route = req.__routeContext ?? {};
    const stack = (payload?.stack as string) || exception.stack || '';
    const locationLine = pickTopTsFrame(stack);

    res.status(status).json({
      ok: false,
      error: {
        code: status,
        message: payload?.message || 'Bad Request',
        details: payload?.details ?? payload,
        route: {
          method: route.method,
          url: route.url,
          controller: route.controller,
          handler: route.handler,
        },
        location: locationLine || undefined, // 예: at ... (src/xxx.ts:123:45)
      },
      timestamp: new Date().toISOString(),
    });
  }
}
