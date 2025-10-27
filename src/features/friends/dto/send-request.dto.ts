// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\dto\send-request.dto.ts
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsUUID } from 'class-validator';

export class SendRequestDto {
  @ApiPropertyOptional({
    example: '11111111-1111-1111-1111-111111111111',
    description: '요청을 보낼 대상 사용자의 UUID (targetEmail과 둘 중 하나만)',
  })
  @IsOptional()
  @IsUUID('all', { message: 'toUserId는 UUIDv4 형식이어야 합니다.' })
  toUserId?: string;

  @ApiPropertyOptional({
    example: 'b@kku.ac.kr',
    description: '요청을 보낼 대상 사용자의 이메일 (toUserId와 둘 중 하나만)',
  })
  @IsOptional()
  @IsEmail({}, { message: '유효한 이메일이 아닙니다.' })
  targetEmail?: string;
}
