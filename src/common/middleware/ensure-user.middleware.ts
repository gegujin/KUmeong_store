// src/common/middleware/ensure-user.middleware.ts
import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { normalizeId } from '../utils/ids';

/**
 * 요청 헤더에 X-User-Id가 없으면 자동 생성하는 미들웨어
 * - 개발/테스트용: 실서비스에서는 JWT 인증 미들웨어로 대체됨
 */
@Injectable()
export class EnsureUserMiddleware implements NestMiddleware {
  use(req: Request, _res: Response, next: NextFunction) {
    let userId = req.headers['x-user-id'];

    // 문자열로 강제 변환
    if (Array.isArray(userId)) userId = userId[0];
    userId = (userId ?? '').toString().trim();

    // ✅ 없거나 비정상 값이면 디폴트 UUID 생성
    if (!userId) {
      const random = Math.floor(Math.random() * 999_999_999_999).toString();
      userId = normalizeId(random);
      req.headers['x-user-id'] = userId;
    } else {
      req.headers['x-user-id'] = normalizeId(userId);
    }

    next();
  }
}
