// src/features/friends/friends.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

// Controller & Service
import { FriendsController } from './friends.controller';
import { FriendsService } from './friends.service';

// Entities
import { FriendEntity } from './entities/friend.entity';
import { FriendRequestEntity } from './entities/friend-request.entity';
import { UserBlockEntity } from './entities/user-block.entity';
import { User } from '../../modules/users/entities/user.entity';

@Module({
  imports: [
    // ✅ Friends 관련 모든 테이블을 한 모듈에 묶어둠
    TypeOrmModule.forFeature([
      FriendEntity,
      FriendRequestEntity,
      UserBlockEntity,
      User,
    ]),
  ],
  controllers: [
    // ✅ /api/v1/friends 이하 라우트 제공
    FriendsController,
  ],
  providers: [
    // ✅ 핵심 비즈니스 로직 (DI)
    FriendsService,
  ],
  exports: [
    // ✅ 다른 모듈(예: ChatsModule 등)에서 FriendsService 주입 가능
    FriendsService,
  ],
})
export class FriendsModule {}
