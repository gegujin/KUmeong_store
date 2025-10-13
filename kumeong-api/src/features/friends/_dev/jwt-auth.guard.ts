// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\_dev\jwt-auth.guard.ts
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { normalizeId } from '../../../common/utils/ids';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();

    // 다양한 표기로 들어올 수 있는 헤더 케이스 흡수
    const rawHeader =
      (req.headers['x-user-id'] ??
        req.headers['X-User-Id'] ??
        req.headers['x-userid'] ??
        '1') as string | number;

    // 문자열화 후 normalize → UUID(8-4-4-4-12)로 통일
    const normalized = normalizeId(String(rawHeader));

    // 개발 편의: normalize 실패 시에도 '1'로 보정
    const userId = normalized || normalizeId('1');

    // req.user 및 헤더 모두에 반영 (파이프라인 일관성)
    req.user = { userId };
    req.headers['x-user-id'] = userId;

    return true; // 개발용: 항상 통과
  }
}
