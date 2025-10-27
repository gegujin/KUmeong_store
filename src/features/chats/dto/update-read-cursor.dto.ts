// src/features/chats/dto/update-read-cursor.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, Length } from 'class-validator';

export class UpdateReadCursorDto {
  @ApiProperty({
    example: 'bb8991e5-0404-40c7-b036-8fb188a9fa12',
    description:
      '커서를 올릴 마지막 메시지의 UUID (빈값이면 서버가 해당 방의 최신 메시지로 보정)',
    required: false,
  })
  @IsOptional()
  @IsString()
  @Length(1, 36)
  lastMessageId?: string | null;
}
