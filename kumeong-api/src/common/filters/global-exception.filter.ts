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

    // 1) Nest의 HttpException은 "있는 그대로" 응답 (상태코드/본문 유지)
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const body = exception.getResponse();

      // 참고용 로그만 남기고 바디는 변조하지 않음
      this.logger.warn(
        `[HttpException] ${req.method} ${req.originalUrl ?? req.url} -> ${status} ${JSON.stringify(body)}`
      );
      return res.status(status).json(body);
    }

    // 2) 그 외 알 수 없는 에러는 500으로 표준화
    const status = HttpStatus.INTERNAL_SERVER_ERROR;
    const message =
      (exception as any)?.message?.toString?.() ?? 'Internal server error';

    // 서버 로그에는 스택을 남김
    const stack = (exception as any)?.stack;
    this.logger.error(
      `[UnknownError] ${req.method} ${req.originalUrl ?? req.url} -> 500 ${message}`,
      stack
    );

    return res.status(status).json({
      statusCode: status,
      message,
      timestamp: new Date().toISOString(),
      path: req.originalUrl ?? req.url,
    });
  }
}
