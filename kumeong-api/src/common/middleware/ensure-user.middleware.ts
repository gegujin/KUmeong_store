// C:\Users\82105\KU-meong Store\kumeong-api\src\common\middleware\ensure-user.middleware.ts
import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { normalizeId } from '../utils/ids';

@Injectable()
export class EnsureUserMiddleware implements NestMiddleware {
  use(req: Request, _res: Response, next: NextFunction) {

    // ---------------------------------------------
    // 🟢 Health Check는 미들웨어를 완전히 건너뛴다
    // ---------------------------------------------
    const url = req.originalUrl;

    // /health, /v1/health, /api/v1/health 전부 허용
    if (
      url === '/health' ||
      url === '/v1/health' ||
      url.startsWith('/api/v1/health')
    ) {
      return next();
    }

    // ---------------------------------------------
    // 기존 EnsureUserMiddleware 로직
    // ---------------------------------------------
    let userId = req.headers['x-user-id'];

    if (Array.isArray(userId)) userId = userId[0];
    userId = (userId ?? '').toString().trim();

    // 없으면 무작위 UUID 부여
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
