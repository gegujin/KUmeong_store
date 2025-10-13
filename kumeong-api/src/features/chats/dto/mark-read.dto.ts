// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\dto\mark-read.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches } from 'class-validator';

// v4 고정이 아닌 일반 UUID 패턴 (8-4-4-4-12, 대소문자 허용)
const UUID_LAX_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class MarkReadDto {
  @ApiProperty({
    example: '11111111-1111-1111-1111-111111111111',
    description: '읽음 표시할 마지막 메시지의 UUID',
  })
  @IsString()
  @Matches(UUID_LAX_REGEX, { message: 'lastMessageId는 UUID 형식(8-4-4-4-12)이어야 합니다.' })
  lastMessageId!: string;
}
