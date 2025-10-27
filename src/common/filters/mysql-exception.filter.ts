import {
  ArgumentsHost,
  BadRequestException,
  Catch,
  ConflictException,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Request, Response } from 'express';

// mysql2 / TypeORM QueryFailedError 형태를 폭넓게 처리
type MySqlLikeError = Partial<Error> & {
  code?: string;        // 'ER_DUP_ENTRY' ...
  errno?: number;       // 1062 ...
  sqlMessage?: string;
  sqlState?: string;    // '23000' (integrity constraint violation) 등
  message?: string;
};

@Catch()
export class MysqlExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx      = host.switchToHttp();
    const res      = ctx.getResponse<Response>();
    const req      = ctx.getRequest<Request>();
    const now      = new Date().toISOString();

    // 이미 HttpException이면 그대로 통과
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const resp   = exception.getResponse();
      return res.status(status).json({
        statusCode: status,
        message: typeof resp === 'string' ? resp : (resp as any).message ?? exception.message,
        error: typeof resp === 'string' ? undefined : (resp as any).error,
        path: req.url,
        timestamp: now,
      });
    }

    // MySQL/TypeORM 에러 매핑
    const e = exception as MySqlLikeError;
    const code  = e.code ?? '';
    const errno = e.errno ?? 0;
    const msg   = (e.sqlMessage || e.message || '').trim();

    // SIGNAL SQLSTATE '45000' → mysql2: errno 1644, code 'ER_SIGNAL_EXCEPTION'
    if (code === 'ER_SIGNAL_EXCEPTION' || errno === 1644) {
      return res.status(HttpStatus.BAD_REQUEST).json({
        statusCode: HttpStatus.BAD_REQUEST,
        message: msg || 'Bad request',
        path: req.url,
        timestamp: now,
      });
    }

    // 무결성/유니크/외래키
    switch (code) {
      case 'ER_DUP_ENTRY':           // 1062: UNIQUE 위반 (uq_...)
      case 'ER_DUP_ENTRY_WITH_KEY_NAME':
        return res.status(HttpStatus.CONFLICT).json({
          statusCode: HttpStatus.CONFLICT,
          message: msg || 'Duplicate entry',
          path: req.url,
          timestamp: now,
        });
      case 'ER_NO_REFERENCED_ROW_2': // 1452: FK 대상 없음 (insert/update)
        return res.status(HttpStatus.BAD_REQUEST).json({
          statusCode: HttpStatus.BAD_REQUEST,
          message: msg || 'Invalid reference (foreign key)',
          path: req.url,
          timestamp: now,
        });
      case 'ER_ROW_IS_REFERENCED_2': // 1451: 참조 중이라 삭제 불가
        return res.status(HttpStatus.CONFLICT).json({
          statusCode: HttpStatus.CONFLICT,
          message: msg || 'Resource is referenced by other rows',
          path: req.url,
          timestamp: now,
        });
      case 'ER_DATA_TOO_LONG':       // 1406: 길이 초과
        return res.status(HttpStatus.BAD_REQUEST).json({
          statusCode: HttpStatus.BAD_REQUEST,
          message: msg || 'Data too long',
          path: req.url,
          timestamp: now,
        });
      case 'ER_CHECK_CONSTRAINT_VIOLATED': // 3819: CHECK 위반
        return res.status(HttpStatus.BAD_REQUEST).json({
          statusCode: HttpStatus.BAD_REQUEST,
          message: msg || 'Check constraint violated',
          path: req.url,
          timestamp: now,
        });
    }

    // SQLSTATE 23000 (무결성 위반) 전반
    if (e.sqlState === '23000') {
      return res.status(HttpStatus.CONFLICT).json({
        statusCode: HttpStatus.CONFLICT,
        message: msg || 'Integrity constraint violation',
        path: req.url,
        timestamp: now,
      });
    }

    // 그 외 알 수 없는 에러는 500
    return res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      message: msg || 'Internal server error',
      path: req.url,
      timestamp: now,
    });
  }
}