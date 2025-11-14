// src/features/chats/chat-rooms.controller.ts
import {
  Body,
  Controller,
  Get,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ChatsService } from './chats.service';
import { JwtAuthGuard } from '../../modules/auth/jwt-auth.guard';

@Controller({ path: 'chat/rooms', version: '1' })
@UseGuards(JwtAuthGuard) // ✅ 컨트롤러 전체 JWT 보호
export class ChatRoomsController {
  constructor(private readonly chats: ChatsService) {}

  /**
   * 거래방 멱등 생성
   * Body: { productId: UUID }
   * 반환: { roomId: string }
   */
  @Post('ensure-trade')
  async ensureTrade(
    // ✅ v1/v4 제한 없이 UUID 문자열만 검증
    @Body('productId') productId: string,
    @Req() req: any,
  ) {
    // ✅ JWT payload: sub 우선, 없으면 id
    const meUserId: string = String(req.user?.sub ?? req.user?.id);
    const room = await this.chats.ensureTradeRoom({ productId, meUserId });
    return { roomId: room.id };
  }

  /**
   * 내 방 목록 (간단형, unreadCount=0 고정)
   * GET /api/v1/chat/rooms?mine=1
   */
  @Get()
  async myRooms(@Query('mine') mine?: string, @Req() req?: any) {
    if (mine === '1' && (req?.user?.sub || req?.user?.id)) {
      const meUserId = String(req.user?.sub ?? req.user?.id);
      const rooms = await this.chats.listMyRooms(meUserId);
      return rooms.map((r) => ({
        id: r.id,
        roomId: r.id,
        unreadCount: 0, // TODO: 실제 계산 로직으로 교체
        lastMessageAt: r.lastMessageAt ?? null,
        lastSnippet: r.lastSnippet ?? null,
        partnerName: r.partnerName ?? null,  // ✅ 추가
        partnerEmail: r.partnerEmail ?? null, // ✅ 추가
      }));
    }
    return [];
  }

  // ⚠️ messages/read 관련 라우트는 ChatsController가 담당 (중복 방지)
}