// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\dto\list-messages.dto.ts
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, Matches, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

// v4 고정이 아닌 느슨한 UUID 패턴 (8-4-4-4-12, 대소문자 허용)
const UUID_LAX_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class ListMessagesQueryDto {
  @ApiPropertyOptional({
    description: '이 메시지 ID(UUID) 이후의 메시지를 가져옵니다.',
    example: '11111111-1111-1111-1111-111111111111',
  })
  @IsOptional()
  @IsString()
  @Matches(UUID_LAX_REGEX, { message: 'afterId는 UUID 형식(8-4-4-4-12)이어야 합니다.' })
  afterId?: string;

  @ApiPropertyOptional({
    description: '가져올 최대 메시지 개수 (1~100)',
    example: 50,
    default: 50,
    maximum: 100,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit: number = 50;
}
