import {
  ArgumentsHost,
  BadRequestException,
  Catch,
  ExceptionFilter,
  HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';
import { ValidationError } from 'class-validator';

@Catch(BadRequestException)
export class ValidationErrorFilter implements ExceptionFilter {
  catch(exception: BadRequestException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const status =
      typeof exception.getStatus === 'function'
        ? exception.getStatus()
        : HttpStatus.BAD_REQUEST;

    const body: any = exception.getResponse?.() ?? {};
    // class-validator의 ValidationPipe는 message에 배열을 넣어줌
    let errors = body?.message;

    if (Array.isArray(errors)) {
      errors = errors.map((e: any) => {
        // 문자열이면 그대로
        if (typeof e === 'string') return e;
        // ValidationError 객체면 constraints를 문자열로 합치기
        if (e && typeof e === 'object' && 'constraints' in e) {
          const c = (e as ValidationError).constraints ?? {};
          return Object.values(c).join(', ');
        }
        try {
          return JSON.stringify(e);
        } catch {
          return String(e);
        }
      });
    } else if (typeof errors === 'string') {
      errors = [errors];
    } else {
      errors = ['Bad Request'];
    }

    res.status(status).json({
      ok: false,
      code: 'VALIDATION_ERROR',
      errors,
    });
  }
}
