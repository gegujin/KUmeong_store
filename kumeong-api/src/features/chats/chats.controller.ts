// src/features/chats/chats.controller.ts
import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  HttpException,
  HttpStatus,
  Param,
  Post,
  Put,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../modules/auth/jwt-auth.guard';
import { ChatsService } from './chats.service';

// ─────────────────────────────────────────────────────────────
// 로컬 ID 유틸 (외부 모듈 제거)
// ─────────────────────────────────────────────────────────────
// v1/v4/variant 강제 X: 하이픈 포함 8-4-4-4-12 형식만 확인
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function assertUuidLike(val: string | null | undefined, name = 'id') {
  if (!val || typeof val !== 'string' || !UUID_RE.test(val)) {
    throw new BadRequestException(`${name} invalid`);
  }
}

/** 단순 정규화: 공백 제거 + 소문자화 (UUID 문자열 전제) */
function normalizeId(val: string): string {
  return String(val ?? '').trim().toLowerCase();
}

@Controller({ path: 'chat', version: '1' })
@UseGuards(JwtAuthGuard)
export class ChatsController {
  constructor(private readonly chats: ChatsService) {}

  // ─────────────────────────────────────────────────────────────
  // 공통 내부 로직: 읽음 처리
  // ─────────────────────────────────────────────────────────────
  private async doMarkRead(req: any, roomIdParam: string, body: any) {
    const meUserId: string | undefined = req.user?.sub || req.user?.id;
    if (!meUserId) throw new UnauthorizedException('UNAUTHENTICATED');

    const roomId = normalizeId(roomIdParam);
    assertUuidLike(roomId, 'roomId');

    // 방 존재/멤버십 검증
    const isMember = await this.chats.ensureRoomMember(roomId, String(meUserId));
    if (!isMember) throw new ForbiddenException('room not found or not a participant');

    // lastMessageId 처리
    let lastMessageId: string | null =
      body?.lastMessageId != null ? String(body.lastMessageId) : null;

    if (lastMessageId) {
      assertUuidLike(lastMessageId, 'lastMessageId');
    } else {
      // 최신 메시지 기준으로 읽음 처리
      if (typeof this.chats.getLatestMessageId === 'function') {
        const latest = await this.chats.getLatestMessageId(roomId);
        if (latest) lastMessageId = String(latest);
      } else if (typeof this.chats.fetchMessagesSinceSeq === 'function') {
        const result = await this.chats.fetchMessagesSinceSeq({
          roomId,
          sinceSeq: 0,
          limit: 1,
          meUserId: String(meUserId),
        });
        const last = Array.isArray(result)
          ? result[result.length - 1]
          : (result as any)?.items?.at?.(-1);
        if (last?.id) lastMessageId = String(last.id);
      }
      if (!lastMessageId) throw new BadRequestException('lastMessageId required');
    }

    // 실제 업데이트
    if (typeof this.chats.markReadTo === 'function') {
      await this.chats.markReadTo({ roomId, userId: String(meUserId), lastMessageId });
    } else if (typeof this.chats.updateReadCursor === 'function') {
      await this.chats.updateReadCursor({
        roomId,
        userId: String(meUserId),
        lastMessageId: String(lastMessageId),
      });
    } else {
      throw new HttpException('read-cursor update method not implemented', HttpStatus.NOT_IMPLEMENTED);
    }

    return { ok: true };
  }

  // ─────────────────────────────────────────────────────────────
  // Endpoints
  // ─────────────────────────────────────────────────────────────

  /**
   * GET /api/v1/chat/friend-room?peerId=<UUID>
   */
  @Get('friend-room')
  async ensureFriendRoom(@Req() req: any, @Query('peerId') peerId?: string) {
    const meUserId: string | undefined = req.user?.sub || req.user?.id;
    if (!meUserId) throw new HttpException('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);
    if (!peerId) throw new BadRequestException('peerId required');
    if (!UUID_RE.test(peerId)) throw new BadRequestException('peerId invalid');
    if (String(meUserId) === String(peerId)) {
      throw new BadRequestException('cannot chat with self');
    }

    const roomId = await this.chats.ensureFriendRoom({
      meUserId: String(meUserId),
      peerUserId: String(peerId),
    });

    return { ok: true, roomId, data: { id: roomId, roomId } };
  }

  /**
   * GET /api/v1/chat/rooms/:roomId/messages?sinceSeq=0&limit=50
   */
  @Get('rooms/:roomId/messages')
  async list(
    @Req() req: any,
    @Param('roomId') roomIdParam: string,
    @Query('sinceSeq') sinceSeqRaw?: string,
    @Query('limit') limitRaw?: string,
  ) {
    const meUserId: string | undefined = req.user?.sub || req.user?.id;
    if (!meUserId) throw new HttpException('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);

    const roomId = normalizeId(roomIdParam);
    assertUuidLike(roomId, 'roomId');

    // ✅ 멤버십 확인 (존재+참여자)
    const isMember = await this.chats.ensureRoomMember(roomId, String(meUserId));
    if (!isMember) throw new ForbiddenException('not a participant');

    const sinceSeq = Math.max(0, parseInt(sinceSeqRaw ?? '0', 10) || 0);
    const limit = Math.min(200, Math.max(1, parseInt(limitRaw ?? '50', 10) || 50));

    const data = await this.chats.fetchMessagesSinceSeq({
      roomId,
      sinceSeq,
      limit,
      meUserId: String(meUserId),
    });
    return { ok: true, data };
  }

  /**
   * POST /api/v1/chat/rooms/:roomId/messages
   */
  @Post('rooms/:roomId/messages')
  async post(@Req() req: any, @Param('roomId') roomIdParam: string, @Body() body: any) {
    const meUserId: string | undefined = req.user?.sub || req.user?.id;
    if (!meUserId) throw new HttpException('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);

    const roomId = normalizeId(roomIdParam);
    assertUuidLike(roomId, 'roomId');

    // ✅ 멤버십 확인 (존재+참여자)
    const isMember = await this.chats.ensureRoomMember(roomId, String(meUserId));
    if (!isMember) throw new ForbiddenException('not a participant');

    const text = (body?.text ?? '').toString().trim();
    if (!text) throw new BadRequestException('text required');

    const saved = await this.chats.appendText({
      roomId,
      senderId: String(meUserId),
      text,
    });

    (global as any).broadcastChatToRoom?.(roomId, saved);
    return { ok: true, data: saved };
  }

  /**
   * PUT /api/v1/chat/rooms/:roomId/read
   * body: { lastMessageId? }
   */
  @Put('rooms/:roomId/read')
  async markRead(@Req() req: any, @Param('roomId') roomId: string, @Body() body: any) {
    return this.doMarkRead(req, roomId, body);
  }
}
