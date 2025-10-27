// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\chats.controller.ts
import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpException,
  HttpStatus,
  Param,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ChatsService } from './chats.service';
import { JwtAuthGuard } from '../../modules/auth/jwt-auth.guard'; // 경로는 프로젝트 구조에 맞추세요

// v1, v4, v5 모두 허용하는 RFC4122 UUID 정규식(서비스와 동일한 기준 권장)
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Controller({ path: 'chat', version: '1' })
@UseGuards(JwtAuthGuard)
export class ChatsController {
  constructor(private readonly chats: ChatsService) {}

  /**
   * GET /api/v1/chat/friend-room?peerId=<UUID>
   * - 친구 DM 방을 보장(없으면 생성, 있으면 조회)하고 roomId를 반환
   * - meUserId는 반드시 JWT에서 추출
   */
  @Get('friend-room')
  async ensureFriendRoom(@Req() req: any, @Query('peerId') peerId?: string) {
    const meUserId: string | undefined = req.user?.sub || req.user?.id;
    if (!meUserId) {
      throw new HttpException('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);
    }
    if (!peerId) {
      throw new BadRequestException('peerId required');
    }
    if (!UUID_RE.test(peerId)) {
      throw new BadRequestException('peerId invalid');
    }
    if (meUserId === peerId) {
      throw new BadRequestException('cannot chat with self');
    }

    const roomId = await this.chats.ensureFriendRoom({
      meUserId,
      peerUserId: peerId,
    });

    return { ok: true, roomId, data: { id: roomId, roomId } };
  }

  /**
   * GET /api/v1/chat/rooms/:roomId/messages?sinceSeq=0&limit=50
   * - ChatApi.fetchMessagesSinceSeq 와 매핑
   * - meUserId는 JWT에서 추출
   * - 방이 없으면 404
   */
  @Get('rooms/:roomId/messages')
  async list(
    @Req() req: any,
    @Param('roomId') roomId: string,
    @Query('sinceSeq') sinceSeqRaw?: string,
    @Query('limit') limitRaw?: string,
  ) {
    const meUserId: string | undefined = req.user?.sub || req.user?.id;
    if (!meUserId) {
      throw new HttpException('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);
    }

    const exists = await this.chats.ensureRoomExists(roomId);
    if (!exists) {
      throw new HttpException('room not found', HttpStatus.NOT_FOUND);
    }

    const sinceSeq = Math.max(0, parseInt(sinceSeqRaw ?? '0', 10) || 0);
    const limit = Math.min(200, Math.max(1, parseInt(limitRaw ?? '50', 10) || 50));

    const data = await this.chats.fetchMessagesSinceSeq({
      roomId,
      sinceSeq,
      limit,
      meUserId,
    });
    return { ok: true, data };
  }

  /**
   * POST /api/v1/chat/rooms/:roomId/messages
   * body: { text }
   * - ChatApi.sendMessage 와 매핑
   * - senderId/roomId 는 JWT/파라미터 기준으로 서버가 결정
   * - ⚠ 방이 없으면 404 (방 생성은 /chat/friend-room에서만 수행)
   */
  @Post('rooms/:roomId/messages')
  async post(@Req() req: any, @Param('roomId') roomId: string, @Body() body: any) {
    const meUserId: string | undefined = req.user?.sub || req.user?.id;
    if (!meUserId) {
      throw new HttpException('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);
    }

    const exists = await this.chats.ensureRoomExists(roomId);
    if (!exists) {
      throw new HttpException('room not found', HttpStatus.NOT_FOUND);
    }

    const text = (body?.text ?? '').toString().trim();
    if (!text) {
      throw new BadRequestException('text required');
    }

    const saved = await this.chats.appendText({
      roomId,
      senderId: meUserId,
      text,
    });

    // WS fan-out (main.ts에서 global.broadcastChatToRoom 정의되어 있어야 함)
    (global as any).broadcastChatToRoom?.(roomId, saved);

    return { ok: true, data: saved };
  }

  /**
   * PUT /api/v1/chat/rooms/:roomId/read_cursor
   * body: { lastMessageId }
   * - ChatApi.markRead 와 매핑
   * - 방이 없으면 404
   */
  @Put('rooms/:roomId/read_cursor')
  async markRead(@Req() req: any, @Param('roomId') roomId: string, @Body() body: any) {
    const meUserId: string | undefined = req.user?.sub || req.user?.id;
    if (!meUserId) {
      throw new HttpException('UNAUTHENTICATED', HttpStatus.UNAUTHORIZED);
    }

    const exists = await this.chats.ensureRoomExists(roomId);
    if (!exists) {
      throw new HttpException('room not found', HttpStatus.NOT_FOUND);
    }

    const lastMessageId = (body?.lastMessageId ?? '').toString();
    if (!lastMessageId) {
      throw new BadRequestException('lastMessageId required');
    }
    // 필요하면 아래처럼 UUID 형식 검증 추가 가능
    // if (!UUID_RE.test(lastMessageId)) throw new BadRequestException('lastMessageId invalid');

    await this.chats.updateReadCursor({ roomId, userId: meUserId, lastMessageId });
    return { ok: true };
  }
}
