// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\chats.controller.ts
import {
  Controller,
  UseGuards,
  Post,
  Param,
  Body,
  Get,
  Query,
  BadRequestException,
  Delete,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ChatsService } from './chats.service';
import { SendMessageDto } from './dto/send-message.dto';
import { ListMessagesQueryDto } from './dto/list-messages.dto';
import { MarkReadDto } from './dto/mark-read.dto';
import { JwtAuthGuard } from '../friends/_dev/jwt-auth.guard';
import { CurrentUserId } from '../friends/_dev/current-user.decorator';
import { normalizeId, isUuid } from '../../common/utils/ids';

@ApiTags('chats')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
// ✅ 여기서는 절대 '/api/...' 쓰지 말 것! 전역 prefix/버저닝이 붙는다.
@Controller('chats')
export class ChatsController {
  constructor(private readonly svc: ChatsService) {}

  /** 숫자/UUID 모두 허용하는 peerId 정규화 */
  private normPeer(peerParam: string): string {
    const peer = normalizeId(peerParam);
    if (!peer || !isUuid(peer)) {
      throw new BadRequestException('peerId must be numeric or UUID');
    }
    return peer;
  }

  // ───────────────────── 메시지 전송 ─────────────────────
  @ApiOperation({ summary: '메시지 전송' })
  @Post(':peerId/messages')
  async send(
    @CurrentUserId() me: string,
    @Param('peerId') peerParam: string,
    @Body() dto: SendMessageDto,
  ) {
    const peerId = this.normPeer(peerParam);
    const text = (dto.text ?? '').trim();
    if (!text) throw new BadRequestException('text is required');

    const data = await this.svc.sendMessage(me, peerId, text);
    return { ok: true, data };
  }

  // ───────────────────── 메시지 목록 ─────────────────────
  @ApiOperation({ summary: '메시지 목록' })
  @Get(':peerId/messages')
  async list(
    @CurrentUserId() me: string,
    @Param('peerId') peerParam: string,
    @Query() q: ListMessagesQueryDto,
  ) {
    const peerId = this.normPeer(peerParam);
    const raw = Number(q.limit ?? 50);
    const limit = Number.isFinite(raw) ? Math.min(Math.max(raw, 1), 100) : 50;

    const data = await this.svc.listMessages(me, peerId, q.afterId, limit);
    return { ok: true, data };
  }

  // ───────────────────── 읽음 표시 ─────────────────────
  @ApiOperation({ summary: '읽음 표시(현재는 no-op stub)' })
  @Post(':peerId/read')
  async read(
    @CurrentUserId() me: string,
    @Param('peerId') peerParam: string,
    @Body() dto: MarkReadDto,
  ) {
    const peerId = this.normPeer(peerParam);
    await this.svc.markRead(me, peerId, dto.lastMessageId);
    return { ok: true };
  }

  // ───────────────────── 신고하기 ─────────────────────
  @ApiOperation({ summary: '상대 신고하기' })
  @Post(':peerId/report')
  async report(
    @CurrentUserId() me: string,
    @Param('peerId') peerParam: string,
    @Body() body: { reason?: string },
  ) {
    const peerId = this.normPeer(peerParam);
    const reason = (body?.reason ?? '').toString().trim() || undefined;
    const data = await this.svc.reportPeer(me, peerId, reason);
    return { ok: true, data };
  }

  // ───────────────────── 차단하기 ─────────────────────
  @ApiOperation({ summary: '상대 차단하기' })
  @Post(':peerId/block')
  async block(
    @CurrentUserId() me: string,
    @Param('peerId') peerParam: string,
  ) {
    const peerId = this.normPeer(peerParam);
    const data = await this.svc.blockPeer(me, peerId);
    return { ok: true, data };
  }

  // ───────────────────── 채팅방 나가기 ─────────────────────
  @ApiOperation({ summary: '채팅방 나가기(대화 기록 삭제 + 방 제거)' })
  @Delete(':peerId')
  async leave(
    @CurrentUserId() me: string,
    @Param('peerId') peerParam: string,
  ) {
    const peerId = this.normPeer(peerParam);
    const data = await this.svc.leaveConversation(me, peerId);
    return { ok: true, data };
  }
}
