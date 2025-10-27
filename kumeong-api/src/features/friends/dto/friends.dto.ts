// src/features/friends/dto/friends.dto.ts
import { IsUUID } from 'class-validator';

export class RequestFriendDto {
  @IsUUID('all')
  targetUserId!: string;
}

export class DecideRequestDto {
  @IsUUID('all')
  requestId!: string;
}
