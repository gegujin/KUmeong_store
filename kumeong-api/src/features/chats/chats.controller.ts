// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\chats.controller.ts
import {
  Body,
  Controller,
  Get,
  Headers,
  HttpException,
  HttpStatus,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ChatsService } from './chats.service';

@Controller('v1/chat')
export class ChatsController {
  constructor(private readonly chats: ChatsService) {}

  /**
   * GET /v1/chat/rooms/:roomId/messages?sinceSeq=0&limit=50
   * - ChatApi.fetchMessagesSinceSeq 와 매핑
   * - X-User-Id 헤더 필수(토큰 없이 단순 헤더 신뢰 방식)
   * - 방이 없으면 404
   */
  @Get('rooms/:roomId/messages')
  async list(
    @Param('roomId') roomId: string,
    @Query('sinceSeq') sinceSeqRaw?: string,
    @Query('limit') limitRaw?: string,
    @Headers('x-user-id') meUserId?: string,
  ) {
    if (!meUserId) {
      throw new HttpException('X-User-Id required', HttpStatus.BAD_REQUEST);
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
   * POST /v1/chat/rooms/:roomId/messages
   * body: { text }
   * - ChatApi.sendMessage 와 매핑
   * - senderId/roomId 는 헤더/파라미터 기준으로 서버가 결정
   * - 방이 없으면 자동 생성 (옵션 B)
   */
  @Post('rooms/:roomId/messages')
  async post(
    @Param('roomId') roomId: string,
    @Body() body: any,
    @Headers('x-user-id') meUserId?: string,
  ) {
    if (!meUserId) {
      throw new HttpException('X-User-Id required', HttpStatus.BAD_REQUEST);
    }

    // ✅ 방 자동 생성/멱등 보장
    await this.chats.ensureRoomExistsOrCreate(roomId);

    const text = (body?.text ?? '').toString().trim();
    if (!text) {
      throw new HttpException('text required', HttpStatus.BAD_REQUEST);
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
   * PUT /v1/chat/rooms/:roomId/read_cursor
   * body: { lastMessageId }
   * - ChatApi.markRead 와 매핑
   * - 방이 없으면 404 (정책 유지)
   */
  @Put('rooms/:roomId/read_cursor')
  async markRead(
    @Param('roomId') roomId: string,
    @Body() body: any,
    @Headers('x-user-id') meUserId?: string,
  ) {
    if (!meUserId) {
      throw new HttpException('X-User-Id required', HttpStatus.BAD_REQUEST);
    }
    const exists = await this.chats.ensureRoomExists(roomId);
    if (!exists) {
      throw new HttpException('room not found', HttpStatus.NOT_FOUND);
    }

    const lastMessageId = (body?.lastMessageId ?? '').toString();
    if (!lastMessageId) {
      throw new HttpException('lastMessageId required', HttpStatus.BAD_REQUEST);
    }

    await this.chats.updateReadCursor({ roomId, userId: meUserId, lastMessageId });
    return { ok: true };
  }
}
