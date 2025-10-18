// src/common/interceptors/success-response.interceptor.ts
import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { Response } from 'express';
import { StreamableFile } from '@nestjs/common';

function isPlainObject(v: unknown): v is Record<string, any> {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}
function isBinaryLike(v: unknown): boolean {
  // 파일/버퍼/스트림은 래핑 금지
  return (
    v instanceof StreamableFile ||
    v instanceof Buffer ||
    v instanceof Uint8Array
    // (주의) Node.js Readable은 타입 의존성 없이 체크하기 어려워 생략
  );
}

@Injectable()
export class SuccessResponseInterceptor implements NestInterceptor {
  intercept(ctx: ExecutionContext, next: CallHandler): Observable<any> {
    const res = ctx.switchToHttp().getResponse<Response>();

    return next.handle().pipe(
      map((data) => {
        // 1) 이미 헤더가 나갔거나(파일 스트림 등) / 204 No Content는 래핑 금지
        if (res.headersSent || res.statusCode === 204) return data;

        // 2) 파일/버퍼/스트림 류는 래핑 금지
        if (isBinaryLike(data)) return data;

        // 3) 컨트롤러에서 명시적으로 비래핑 요청한 경우 (원하면 사용)
        if (res.getHeader('x-no-wrap')) return data;

        // 4) 이미 래핑된 형태 또는 특수 응답들은 통과
        if (
          isPlainObject(data) &&
          (
            data.ok === true ||
            'deleted' in data ||          // delete 응답 등
            ('data' in data && 'meta' in data) || // 페이지네이션 등
            ('statusCode' in data && res.statusCode < 400) // 커스텀 성공바디
          )
        ) {
          return data;
        }

        // 5) 그 외 "성공"만 표준 래핑
        return { ok: true, data };
      }),
    );
  }
}
