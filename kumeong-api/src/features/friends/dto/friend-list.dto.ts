// src/features/friends/dto/friend-list.dto.ts

export interface FriendListItemDto {
  userId: string;
  displayName: string;
  trustScore: number;
  reviewCount: number;
  tradeCount: number;
  friendedAt: string; // ISO
}
