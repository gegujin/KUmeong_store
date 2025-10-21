// src/common/filters/global-exception.filter.ts
import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus } from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest<Request>();
    const res = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | string[] = 'Internal server error';
    let details: any;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const resp = exception.getResponse();
      if (typeof resp === 'string') message = resp;
      else if (resp && typeof resp === 'object') {
        const r: any = resp;
        message = r.message ?? r.error ?? message;
        if (Array.isArray(r.message)) details = r.message;
      }
    } else if (exception instanceof Error) {
      message = exception.message || message;
    }

    const body: any = {
      ok: false,
      error: {
        code: status,
        message: Array.isArray(message) ? message.join(', ') : message,
      },
      path: req.originalUrl ?? req.url,
      timestamp: new Date().toISOString(),
    };
    if (details) body.error.details = details;

    res.status(status).json(body);
  }
}
