// // C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\friends.controller.ts
import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
  ParseUUIDPipe,
  BadRequestException,
  Patch,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FriendsService } from './friends.service';
import { SendRequestDto } from './dto/send-request.dto';
import { AcceptRequestDto } from './dto/accept-request.dto';

import { JwtAuthGuard } from './_dev/jwt-auth.guard';
import { CurrentUserId } from './_dev/current-user.decorator';

@ApiTags('friends')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'friends', version: '1' })
export class FriendsController {
  constructor(private readonly svc: FriendsService) {}

  // ─────────────────────────────────────────────────────────────
  // 친구 요청 보내기 (이메일 or UUID 한 엔드포인트)
  // POST /v1/friends/requests
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '친구 요청 보내기(이메일 또는 UUID)' })
  @Post('requests')
  async send(@CurrentUserId() me: string, @Body() dto: SendRequestDto) {
    const { toUserId, targetEmail } = dto ?? {};
    if (!toUserId && !targetEmail) {
      throw new BadRequestException('toUserId 또는 targetEmail 중 하나가 필요합니다.');
    }
    await this.svc.sendRequestMixed(me, { toUserId, targetEmail });
    return { ok: true };
  }

  // (선택) 레거시: 이메일 전용
  @ApiOperation({ summary: '친구 요청 보내기(상대 이메일로)' })
  @Post('requests/by-email')
  async sendByEmail(
    @CurrentUserId() me: string,
    @Body('toEmail') toEmail: string,
  ) {
    const email = (toEmail ?? '').trim();
    if (!email || !email.includes('@')) {
      throw new BadRequestException('유효한 이메일이 아닙니다.');
    }
    await this.svc.sendRequestByEmail(me, email);
    return { ok: true };
  }

  // ─────────────────────────────────────────────────────────────
  // 받은/보낸 요청 목록 — ?box=incoming|outgoing (default=incoming)
  // GET /v1/friends/requests?box=incoming|outgoing
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '받은/보낸 요청 목록 (box 쿼리 지원)' })
  @Get('requests')
  async listReq(@CurrentUserId() me: string, @Query('box') box?: string) {
    const normalized = box === 'outgoing' ? 'outgoing' : 'incoming';
    const data = await this.svc.listRequestsBox(me, normalized);
    return { ok: true, data };
  }

  // ─────────────────────────────────────────────────────────────
  // 요청 상태 변경 (요청 ID = UUID)
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '요청 수락' })
  @Patch('requests/:id/accept')
  async accept(
    @CurrentUserId() me: string,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
    @Body() _dto: AcceptRequestDto,
  ) {
    await this.svc.acceptRequest(me, id);
    return { ok: true };
  }

  @ApiOperation({ summary: '요청 거절' })
  @Post('requests/:id/reject')
  async reject(
    @CurrentUserId() me: string,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ) {
    await this.svc.rejectRequest(me, id);
    return { ok: true };
  }

  @ApiOperation({ summary: '요청 취소(보낸 사람만)' })
  @Post('requests/:id/cancel')
  async cancel(
    @CurrentUserId() me: string,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ) {
    await this.svc.cancelRequest(me, id);
    return { ok: true };
  }

  // ─────────────────────────────────────────────────────────────
  // 친구 목록
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '친구 목록' })
  @Get()
  async list(@CurrentUserId() me: string) {
    const data = await this.svc.listFriends(me);
    return { ok: true, data };
  }

  // ─────────────────────────────────────────────────────────────
  // 언프렌드/차단/차단해제 — 대상은 사용자 UUID
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '언프렌드' })
  @Delete(':peerId')
  async unfriend(
    @CurrentUserId() me: string,
    @Param('peerId', new ParseUUIDPipe({ version: '4' })) peerId: string,
  ) {
    await this.svc.unfriend(me, peerId);
    return { ok: true };
  }

  @ApiOperation({ summary: '차단' })
  @Post('blocks/:targetId')
  async block(
    @CurrentUserId() me: string,
    @Param('targetId', new ParseUUIDPipe({ version: '4' })) targetId: string,
  ) {
    await this.svc.block(me, targetId);
    return { ok: true };
  }

  @ApiOperation({ summary: '차단 해제' })
  @Delete('blocks/:targetId')
  async unblock(
    @CurrentUserId() me: string,
    @Param('targetId', new ParseUUIDPipe({ version: '4' })) targetId: string,
  ) {
    await this.svc.unblock(me, targetId);
    return { ok: true };
  }
}
