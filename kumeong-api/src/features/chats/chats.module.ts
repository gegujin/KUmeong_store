// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\chats.module.ts
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
    TypeOrmModule.forFeature([
      Conversation,
      ConversationMessage,
    ]),
  ],
  controllers: [ChatsController],
  providers: [ChatsService],
  // ✅ 다른 모듈에서 ChatsService 또는 Repo를 재사용할 수 있게 export
  exports: [ChatsService, TypeOrmModule],
})
export class ChatsModule {}
