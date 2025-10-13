// src/features/friends/dto/create-friend-request.dto.ts
import { IsUUID } from 'class-validator';

export class CreateFriendRequestDto {
  @IsUUID('4')
  toUserId!: string;
}
