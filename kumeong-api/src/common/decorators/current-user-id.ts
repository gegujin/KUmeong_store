// src/common/decorators/current-user-id.ts
import { createParamDecorator, ExecutionContext, UnauthorizedException } from '@nestjs/common';

/**
 * JWT payload.sub를 string으로 추출하는 커스텀 데코레이터
 */
export const CurrentUserId = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): string => {
    const req = ctx.switchToHttp().getRequest();
    const user = req.user;
    const id = user?.sub;
    if (!id || typeof id !== 'string') {
      throw new UnauthorizedException('Invalid user context');
    }
    return id;
  },
);
