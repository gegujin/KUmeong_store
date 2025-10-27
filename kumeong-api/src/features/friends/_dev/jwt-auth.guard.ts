// src/features/friends/_dev/jwt-auth.guard.ts
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { normalizeId } from '../../../common/utils/ids';

function decodeJwtPayload(token: string): any | null {
  try {
    const [, payload] = token.split('.');
    const json = Buffer.from(payload.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8');
    return JSON.parse(json);
  } catch {
    return null;
  }
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();

    // 1) Bearer 토큰에서 payload 추출 (id/sub/userId 지원)
    const auth = (req.headers['authorization'] ?? '') as string;
    let candidate: string | undefined;
    if (auth.startsWith('Bearer ')) {
      const token = auth.slice(7).trim();
      const p = decodeJwtPayload(token);
      candidate = p?.id ?? p?.sub ?? p?.userId;
    }

    // 2) X-User-Id 헤더 fallback
    const rawHeader =
      candidate ??
      (req.headers['x-user-id'] as string | undefined) ??
      (req.headers['x-userid'] as string | undefined) ??
      (req.headers['X-User-Id'] as unknown as string | undefined);

    // 3) UUID 정규화 시도
    const normalized = rawHeader ? normalizeId(String(rawHeader)) : undefined;

    // 4) req.user에 표준 키들 모두 셋업 (id/sub/userId 모두 같은 값)
    //    헤더도 맞춰서 주입 (디버깅 편의)
    if (normalized) {
      req.user = { id: normalized, sub: normalized, userId: normalized };
      req.headers['x-user-id'] = normalized;
    } else {
      // 개발용: id가 비면 요청은 통과시키되 나중에 데코레이터에서 명확히 에러
      req.user = req.user ?? {};
    }

    return true; // 개발용: 항상 통과
  }
}
