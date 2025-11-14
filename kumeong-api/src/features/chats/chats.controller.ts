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
    const svc: any = this.chats as any;
    if (typeof svc.ensureRoomMember === 'function') {
      const isMember = await svc.ensureRoomMember(roomId, String(meUserId));
      if (!isMember) throw new ForbiddenException('room not found or not a participant');
    } else if (typeof svc.ensureRoomExists === 'function') {
      const exists = await svc.ensureRoomExists(roomId);
      if (!exists) throw new HttpException('room not found', HttpStatus.NOT_FOUND);
    }

    // lastMessageId 처리
    let lastMessageId: string | null =
      body?.lastMessageId != null ? String(body.lastMessageId) : null;

    if (lastMessageId) {
      assertUuidLike(lastMessageId, 'lastMessageId');
    } else {
      if (typeof svc.markReadTo !== 'function' && typeof svc.updateReadCursor === 'function') {
        if (typeof svc.getLatestMessageId === 'function') {
          const latest = await svc.getLatestMessageId(roomId);
          if (latest) lastMessageId = String(latest);
        } else if (typeof svc.fetchMessagesSinceSeq === 'function') {
          const result = await svc.fetchMessagesSinceSeq({
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
    }

    // 실제 업데이트
    if (typeof svc.markReadTo === 'function') {
      await svc.markReadTo({ roomId, userId: String(meUserId), lastMessageId });
    } else if (typeof svc.updateReadCursor === 'function') {
      await svc.updateReadCursor({
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

  // ⭐ NEW
  /**
   * ✅ GET /api/v1/chat/rooms?mine=1&limit=50
   *  - 프런트 채팅 목록(친구 + 거래방) 조회
   */
  @Get('rooms')
  async getMyRooms(
    @Req() req: any,
    @Query('mine') mine = '1',
    @Query('limit') limitRaw = '50',
  ) {
    const meUserId: string | undefined = req.user?.sub || req.user?.id;
    if (!meUserId) {
      throw new HttpException('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);
    }

    const onlyMine =
      mine === '1' || mine === 'true' || mine === 'yes' || mine === 'Y' || mine === 'y';

    let limit = parseInt(limitRaw ?? '50', 10);
    if (Number.isNaN(limit)) limit = 50;
    limit = Math.min(200, Math.max(1, limit));

    // ChatsService 쪽에 listMyRooms 구현 필요 (opts 형태로 설계)
    const items = await this.chats.listMyRooms({
      meUserId: String(meUserId),
      mine: onlyMine,
      limit,
    });

    return { ok: true, data: items };
  }

  /**
   * ✅ POST /api/v1/chat/rooms/ensure-trade
   * Body: { productId: UUID }
   * Return: { ok, roomId, data:{ id, roomId } }
   */
  @Post('rooms/ensure-trade')
  async ensureTrade(@Req() req: any, @Body('productId') productId?: string) {
    const meUserId: string | undefined = req.user?.sub || req.user?.id;
    if (!meUserId) throw new HttpException('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);

    const pid = normalizeId(String(productId ?? ''));
    assertUuidLike(pid, 'productId');

    const room = await this.chats.ensureTradeRoom({
      productId: pid,
      meUserId: String(meUserId),
    });

    const roomId = room.id;
    return { ok: true, roomId, data: { id: roomId, roomId } };
  }

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

    const exists = await this.chats.ensureRoomExists(roomId);
    if (!exists) throw new HttpException('room not found', HttpStatus.NOT_FOUND);

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

    const exists = await this.chats.ensureRoomExists(roomId);
    if (!exists) throw new HttpException('room not found', HttpStatus.NOT_FOUND);

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
