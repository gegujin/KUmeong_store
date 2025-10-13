// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\dto\act-on-request.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

export class ActOnRequestDto {
  @ApiProperty({
    example: '44444444-4444-4444-4444-444444444444',
    description: '대상 친구 요청의 UUID',
  })
  @IsUUID('4', { message: 'requestId는 UUIDv4 형식이어야 합니다.' })
  requestId!: string;
}
