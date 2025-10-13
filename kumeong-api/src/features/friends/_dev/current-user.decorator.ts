// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\_dev\current-user.decorator.ts
import { createParamDecorator, ExecutionContext, BadRequestException } from '@nestjs/common';
import { normalizeId } from '../../../common/utils/ids';

export const CurrentUserId = createParamDecorator((data: unknown, ctx: ExecutionContext) => {
  const req = ctx.switchToHttp().getRequest();
  const raw = req.headers['x-user-id'];

  // 헤더 미존재 시 예외 처리 (필수)
  if (!raw || typeof raw !== 'string') {
    throw new BadRequestException('X-User-Id 헤더가 필요합니다.');
  }

  const id = normalizeId(raw);
  if (!id) {
    throw new BadRequestException('X-User-Id 형식이 올바르지 않습니다.');
  }

  return id;
});
