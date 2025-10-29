// src/features/chats/dto/create-message.dto.ts
import { IsString, IsUUID, IsOptional, Length } from 'class-validator';

export class CreateMessageDto {
  @IsString()
  @Length(1, 4000)
  text!: string;             // ✅ ! 추가 (TS strict 오류 해결)

  @IsOptional()
  @IsUUID()
  clientMessageId?: string;  // ✅ optional
}
