import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { ChatsController } from './chats.controller';
import { ChatsService } from './chats.service';
import { Conversation } from './entities/conversation.entity';
import { ConversationMessage } from './entities/conversation-message.entity';

/**
 * ChatsModule
 * - Conversation, ConversationMessage 엔티티 등록
 * - ChatsController / ChatsService 등록
 * - DataSource는 TypeOrmModule.forRoot()에서 주입되므로 별도 import 불필요
 */
@Module({
  imports: [
    // ✅ TypeORM 엔티티 등록 (레포지토리 자동 주입 활성화)
    TypeOrmModule.forFeature([Conversation, ConversationMessage]),
  ],
  controllers: [ChatsController],
  providers: [ChatsService],
  exports: [ChatsService],
})
export class ChatsModule {}
