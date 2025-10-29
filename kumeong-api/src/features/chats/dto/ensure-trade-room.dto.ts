// src/features/chats/dto/ensure-trade-room.dto.ts
import { IsUUID } from 'class-validator';

export class EnsureTradeRoomDto {
  // ✅ v1, v4 둘 다 허용됨 (네 프로젝트 전제와 일치)
  @IsUUID(undefined, { message: 'productId must be UUID' })
  productId!: string;
}
