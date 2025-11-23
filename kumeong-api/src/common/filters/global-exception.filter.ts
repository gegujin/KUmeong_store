// src/common/filters/global-exception.filter.ts
import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest<Request>();
    const res = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | string[] = 'Internal server error';
    let details: any = null;

    // ============================
    // Nest HttpException
    // ============================
    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const resp = exception.getResponse();

      if (typeof resp === 'string') {
        message = resp;
      } else if (resp && typeof resp === 'object') {
        const r: any = resp;
        message = r.message ?? r.error ?? message;
        if (Array.isArray(r.message)) {
          details = r.message;
        }
      }
    }

    // ============================
    // 일반 Error 객체
    // ============================
    else if (exception instanceof Error) {
      message = exception.message || message;
    }

    // ============================
    // 서버 콘솔 로그 강화 (K8s 용)
    // ============================
    this.logger.error(
      `[${req.method}] ${req.originalUrl} (${status}) :: ${message}`,
      exception instanceof Error ? exception.stack : undefined,
    );

    // ============================
    // 프런트로 내려가는 JSON 구조 (안전하게 최소 정보만)
    // ============================
    const body: any = {
      ok: false,
      error: {
        code: status,
        message: Array.isArray(message) ? message.join(', ') : message,
      },
      path: req.originalUrl ?? req.url,
      timestamp: new Date().toISOString(),
    };

    if (details) {
      body.error.details = details;
    }

    res.status(status).json(body);
  }
}
