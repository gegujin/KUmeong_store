// src/common/interceptors/success-response.interceptor.ts
import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

function isPlainObject(v: unknown): v is Record<string, any> {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

@Injectable()
export class SuccessResponseInterceptor implements NestInterceptor {
  intercept(_ctx: ExecutionContext, next: CallHandler): Observable<any> {
    return next.handle().pipe(
      map((data) => {
        // 이미 래핑됐거나 삭제 응답이면 통과
        if (isPlainObject(data) && (data.ok === true || 'deleted' in data)) return data;
        return { ok: true, data };
      }),
    );
  }
}
