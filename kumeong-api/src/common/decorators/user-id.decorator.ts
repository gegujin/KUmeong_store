//C:\Users\82105\KU-meong Store\kumeong-api\src\common\decorators\user-id.decorator.ts
import { createParamDecorator, ExecutionContext, BadRequestException } from '@nestjs/common';

export const UserIdFromHeader = createParamDecorator((data: unknown, ctx: ExecutionContext) => {
  const req = ctx.switchToHttp().getRequest();
  const id = (req.headers['x-user-id'] ?? req.headers['X-User-Id']) as string | undefined;
  if (!id || typeof id !== 'string') {
    throw new BadRequestException('X-User-Id header is required');
  }
  return id;
});
