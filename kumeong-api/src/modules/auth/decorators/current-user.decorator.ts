// src/modules/auth/decorators/current-user.decorator.ts
import { createParamDecorator, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import type { SafeUser } from '../types/user.types';

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): SafeUser => {
    const req = ctx.switchToHttp().getRequest();
    const u = req?.user ?? {};

    // 🔑 sub(id), id, userId 순서로 안전하게 추출
    const id: string | undefined = u.id ?? u.sub ?? u.userId;
    if (!id) {
      // 가드가 붙었는데도 여기 오면 비정상 — 명확한 401 처리
      throw new UnauthorizedException('No authenticated user in request');
    }

    // 필요한 필드만 안전하게 리턴 (SafeUser 타입에 맞춰 매핑)
    return {
      id,
      email: u.email,
      role: u.role,   // 프로젝트에 따라 u.scopes 등으로 바꿀 수 있음
    } as SafeUser;
  },
);
