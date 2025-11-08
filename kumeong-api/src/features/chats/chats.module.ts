import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { ChatsController } from './chats.controller';
import { ChatsService } from './chats.service';
import { Conversation } from './entities/conversation.entity';
import { ConversationMessage } from './entities/conversation-message.entity';

// ✅ 추가
import { ChatRoomsController } from './chat-rooms.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([Conversation, ConversationMessage]),
    // ChatMessage 엔티티 레포를 쓰고 싶다면 여기에 추가하면 됨.
  ],
  controllers: [ChatsController, ChatRoomsController], // ✅ ChatRoomsController 등록
  providers: [ChatsService],
  exports: [ChatsService],
})
export class ChatsModule {}
