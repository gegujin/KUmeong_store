// src/features/friends/friends.controller.ts
import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
  BadRequestException,
  Patch,
  Query,
  HttpCode,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FriendsService } from './friends.service';
import { SendRequestDto } from './dto/send-request.dto';
import { JwtAuthGuard } from './_dev/jwt-auth.guard';
import { CurrentUserId } from './_dev/current-user.decorator';
import { FriendRequestByEmailDto } from './dto/friend-request-by-email.dto';

@ApiTags('friends')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'friends', version: '1' })
export class FriendsController {
  constructor(private readonly friendsService: FriendsService) {}

  // ─────────────────────────────────────────────────────────────
  // A) 친구 요청(혼합: toUserId 또는 targetEmail)
  //    POST /api/v1/friends/requests
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '친구 요청 보내기(이메일 또는 UUID)' })
  @Post('requests')
  @HttpCode(200)
  async send(@CurrentUserId() me: string, @Body() dto: SendRequestDto) {
    const { toUserId, targetEmail } = dto ?? {};
    if (!toUserId && !targetEmail) {
      throw new BadRequestException('toUserId 또는 targetEmail 중 하나가 필요합니다.');
    }
    const res = await this.friendsService.sendRequestMixed(me, { toUserId, targetEmail });
    // 응답 통일: 스모크 스크립트가 가장 쉽게 인식
    return res ? { ok: true, id: res.id, status: res.status, dedup: !!res.dedup } : { ok: true };
  }

  // ─────────────────────────────────────────────────────────────
  // B) 이메일 전용(레거시/폴백): POST /api/v1/friends/requests/by-email
  //    { "email": "...@ac.kr" } 또는 { "toEmail": "...@ac.kr" }
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '친구 요청 보내기(상대 이메일로)' })
  @Post('requests/by-email')
  @HttpCode(200)
  async sendByEmail(
    @CurrentUserId() me: string,
    @Body() dto: FriendRequestByEmailDto,
  ) {
    const res = await this.friendsService.sendRequestByEmail(me, dto.email);
    return { ok: true, id: res.id, status: res.status, dedup: !!res.dedup };
  }

  // ─────────────────────────────────────────────────────────────
  // 받은/보낸 요청 목록: GET /api/v1/friends/requests?box=incoming|outgoing
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '받은/보낸 요청 목록 (box 쿼리 지원)' })
  @Get('requests')
  async listReq(@CurrentUserId() me: string, @Query('box') box?: string) {
    const normalized: 'incoming' | 'outgoing' = box === 'outgoing' ? 'outgoing' : 'incoming';
    const data = await this.friendsService.listRequestsBox(me, normalized);
    return { ok: true, data };
  }

  // ─────────────────────────────────────────────────────────────
  // 요청 상태 변경 (다중 폴백) — 모두 200 응답 통일
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '요청 수락 (id, POST)' })
  @Post('requests/:id/accept')
  @HttpCode(200)
  async acceptFriendRequestPost(@CurrentUserId() me: string, @Param('id') id: string) {
    return this.friendsService.accept(id, me);
  }

  @ApiOperation({ summary: '요청 상태 변경 (id, PATCH status)' })
  @Patch('requests/:id')
  @HttpCode(200)
  async updateFriendRequestStatus(
    @CurrentUserId() me: string,
    @Param('id') id: string,
    @Body('status') status?: string,
  ) {
    const s = String(status ?? '').toUpperCase();
    if (s !== 'ACCEPTED') {
      throw new BadRequestException(`status must be 'ACCEPTED'`);
    }
    return this.friendsService.accept(id, me);
  }

  @ApiOperation({ summary: '요청 수락 (body: requestId|id)' })
  @Post('requests/accept')
  @HttpCode(200)
  async acceptFriendRequestBody(
    @CurrentUserId() me: string,
    @Body('requestId') requestId?: string,
    @Body('id') idFallback?: string,
  ) {
    const rid = requestId ?? idFallback;
    if (!rid) throw new BadRequestException('requestId (or id) is required');
    return this.friendsService.accept(rid, me);
  }

  @ApiOperation({ summary: '요청 결정 (body: requestId + action=accept)' })
  @Post('requests/decide')
  @HttpCode(200)
  async decideFriendRequest(
    @CurrentUserId() me: string,
    @Body('requestId') requestId?: string,
    @Body('action') action?: string,
  ) {
    if (!requestId) throw new BadRequestException('requestId is required');
    if (String(action ?? '').toLowerCase() !== 'accept') {
      throw new BadRequestException("action must be 'accept'");
    }
    return this.friendsService.accept(requestId, me);
  }

  // ─────────────────────────────────────────────────────────────
  // 요청 거절 / 취소
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '요청 거절' })
  @Post('requests/:id/reject')
  @HttpCode(200)
  async reject(
    @CurrentUserId() me: string,
    @Param('id') id: string,
  ) {
    await this.friendsService.rejectRequest(me, id);
    return { ok: true };
  }

  @ApiOperation({ summary: '요청 취소(보낸 사람만)' })
  @Post('requests/:id/cancel')
  @HttpCode(200)
  async cancel(
    @CurrentUserId() me: string,
    @Param('id') id: string,
  ) {
    await this.friendsService.cancelRequest(me, id);
    return { ok: true };
  }


  // ─────────────────────────────────────────────────────────────
  // 친구 목록
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '친구 목록' })
  @Get()
  async list(@CurrentUserId() meId: string) {
    const data = await this.friendsService.listFriends(meId);
    return { ok: true, data };
  }

  // (디버그) Raw SQL 기반 결과 보기
  @ApiOperation({ summary: '(디버그) raw 결과 보기' })
  @Get('_debug/raw')
  async listRaw(@CurrentUserId() meId: string) {
    const data = await this.friendsService.listFriends(meId);
    return { ok: true, meId, data };
  }

  // ─────────────────────────────────────────────────────────────
  // 언프렌드/차단/차단해제 — 대상은 사용자 UUID
  // ─────────────────────────────────────────────────────────────
  @ApiOperation({ summary: '언프렌드' })
  @Delete(':peerId')
  async unfriend(
    @CurrentUserId() me: string,
    @Param('peerId') peerId: string,
  ) {
    await this.friendsService.unfriend(me, peerId);
    return { ok: true };
  }

  @ApiOperation({ summary: '차단' })
  @Post('blocks/:targetId')
  async block(
    @CurrentUserId() me: string,
    @Param('targetId') targetId: string,
  ) {
    await this.friendsService.block(me, targetId);
    return { ok: true };
  }

  @ApiOperation({ summary: '차단 해제' })
  @Delete('blocks/:targetId')
  async unblock(
    @CurrentUserId() me: string,
    @Param('targetId') targetId: string,
  ) {
    await this.friendsService.unblock(me, targetId);
    return { ok: true };
  }
}
