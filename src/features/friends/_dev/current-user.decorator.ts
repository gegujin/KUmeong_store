// src/features/friends/_dev/current-user.decorator.ts
import { createParamDecorator, ExecutionContext, BadRequestException } from '@nestjs/common';
import { normalizeId } from '../../../common/utils/ids';

export const CurrentUserId = createParamDecorator((_data: unknown, ctx: ExecutionContext) => {
  const req = ctx.switchToHttp().getRequest();
  const u = req?.user ?? {};

  // 1) req.user 우선
  const fromReqUser = (u.id ?? u.sub ?? u.userId) as string | undefined;

  // 2) 헤더 fallback
  const fromHeader =
    (req.headers['x-user-id'] as string | undefined) ??
    (req.headers['x-userid'] as string | undefined) ??
    (req.headers['X-User-Id'] as unknown as string | undefined);

  const raw = fromReqUser ?? fromHeader;
  const id = raw ? normalizeId(String(raw)) : undefined;

  if (!id) {
    throw new BadRequestException('인증 정보에 사용자 ID가 없습니다. (req.user.id/sub/userId 또는 X-User-Id)');
  }
  return id;
});
