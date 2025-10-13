// C:\Users\82105\KU-meong Store\kumeong-api\src\features\notifications\notifications.controller.ts
import { Controller, Get, Post, Delete, Param, ParseIntPipe, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';

// 테스트용 가드(헤더 X-User-Id). 실제 JWT 생기면 교체
import { JwtAuthGuard } from '../friends/_dev/jwt-auth.guard';
import { CurrentUserId } from '../friends/_dev/current-user.decorator';

@ApiTags('notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'notifications', version: '1' })
export class NotificationsController {
  constructor(private readonly svc: NotificationsService) {}

  @ApiOperation({ summary: '내 알림 목록' })
  @ApiQuery({ name: 'unread', required: false, description: '1(또는 true)이면 미읽음만' })
  @Get()
  async list(@CurrentUserId() me: number, @Query('unread') unread?: string) {
    const onlyUnread = unread === '1' || unread === 'true';
    const items = await this.svc.list(me, onlyUnread);
    return { ok: true, data: items };
  }

  @ApiOperation({ summary: '알림 읽음 처리' })
  @Post(':id/read')
  async read(@CurrentUserId() me: number, @Param('id', ParseIntPipe) id: number) {
    await this.svc.markRead(me, id);
    return { ok: true };
  }

  @ApiOperation({ summary: '알림 삭제' })
  @Delete(':id')
  async remove(@CurrentUserId() me: number, @Param('id', ParseIntPipe) id: number) {
    await this.svc.remove(me, id);
    return { ok: true };
  }
}
