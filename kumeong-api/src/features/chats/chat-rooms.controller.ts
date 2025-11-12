// src/features/chats/chat-rooms.controller.ts
import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Post,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { ChatsService } from './chats.service';
import { JwtAuthGuard } from '../../modules/auth/jwt-auth.guard';

@Controller({ path: 'chat/rooms', version: '1' })
@UseGuards(JwtAuthGuard) // ✅ 컨트롤러 전체 JWT 보호
export class ChatRoomsController {
  constructor(private readonly chats: ChatsService) {}

  // 서비스와 동일한 느슨 검증(36자, 하이픈 포함/버전 불문)
  private static readonly UUID36_LOOSE = /^[0-9a-f-]{36}$/i;

  /**
   * 거래방 멱등 생성
   * POST /api/v1/chat/rooms/ensure-trade
   * Body: { productId: UUID(느슨 검증) }
   * 반환: { roomId: string }
   */
  @Post('ensure-trade')
  async ensureTrade(
    @Body('productId') productId: string,
    @Req() req: any,
  ) {
    // ✅ JWT payload: sub 우선, 없으면 id
    const meUserId: string = String(req?.user?.sub ?? req?.user?.id ?? '');

    if (!meUserId) {
      throw new UnauthorizedException('UNAUTHORIZED');
    }
    // 컨트롤러 단계에서도 서비스와 같은 룰로 1차 필터링
    if (typeof productId !== 'string' || !ChatRoomsController.UUID36_LOOSE.test(productId)) {
      throw new BadRequestException('INVALID_PRODUCT_ID');
    }

    const room = await this.chats.ensureTradeRoom({ productId, meUserId });
    return { roomId: room.id };
  }

  /**
   * 내 방 목록 (간단형, unreadCount=0 고정)
   * GET /api/v1/chat/rooms?mine=1
   */
  @Get()
  async myRooms(@Query('mine') mine?: string, @Req() req?: any) {
    const meUserId = String(req?.user?.sub ?? req?.user?.id ?? '');
    if (mine === '1' && meUserId) {
      const rooms = await this.chats.listMyRooms(meUserId);
      return rooms.map((r: any) => ({
        id: r.id,
        roomId: r.id,
        unreadCount: 0, // TODO: 실제 계산 로직으로 교체
        lastMessageAt: r.lastMessageAt ?? null,
        lastSnippet: r.lastSnippet ?? null,
      }));
    }
    return [];
  }

  // ⚠️ messages/read 관련 라우트는 별도 MessagesController가 담당(중복 방지)
}
