// src/features/friends/friend-requests.controller.ts
import { Controller, Post, Body, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FriendRequestsService } from './friend-requests.service';
import { CreateByEmailDto } from './dto/friend-requests.dto';

@Controller('friends/requests')
@UseGuards(AuthGuard('jwt'))
export class FriendRequestsController {
  constructor(private readonly svc: FriendRequestsService) {}

  private me(req: any) { return req.user.id as string; }

  /** 친구요청 생성 (이메일) */
  @Post('by-email')
  createByEmail(@Body() dto: CreateByEmailDto, @Req() req: any) {
    return this.svc.createByEmail(this.me(req), dto.email);
  }

  /** 친구요청 취소 (보낸 사람, 이메일) */
  @Post('by-email/cancel')
  cancelByEmail(@Body() dto: CreateByEmailDto, @Req() req: any) {
    return this.svc.cancelByEmail(this.me(req), dto.email);
  }

  /** 친구요청 수락 (받은 사람, 이메일) */
  @Post('by-email/accept')
  acceptByEmail(@Body() dto: CreateByEmailDto, @Req() req: any) {
    return this.svc.decideByEmail(this.me(req), dto.email, 'accept');
  }

  /** 친구요청 거절 (받은 사람, 이메일) */
  @Post('by-email/reject')
  rejectByEmail(@Body() dto: CreateByEmailDto, @Req() req: any) {
    return this.svc.decideByEmail(this.me(req), dto.email, 'reject');
  }

  // ⛔ 목록 조회(GET)는 friends.controller.ts의 GET /friends/requests와 충돌하므로 제거했습니다.
}
