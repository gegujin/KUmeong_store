// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\friends.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { FriendsController } from './friends.controller';
import { FriendsService } from './friends.service';

import { FriendEntity } from './entities/friend.entity';
import { FriendRequestEntity } from './entities/friend-request.entity';
import { UserBlockEntity } from './entities/user-block.entity';
import { User } from '../../modules/users/entities/user.entity'; // ✅ 경로/클래스명 수정

@Module({
  imports: [
    TypeOrmModule.forFeature([
      FriendEntity,
      FriendRequestEntity,
      UserBlockEntity,
      User,
    ]),
  ],
  controllers: [FriendsController],
  providers: [FriendsService],
  exports: [FriendsService],
})
export class FriendsModule {}
