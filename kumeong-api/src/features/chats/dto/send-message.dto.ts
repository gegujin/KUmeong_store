// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\dto\send-message.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length } from 'class-validator';

/**
 * 메시지 전송 DTO
 * - text 필드만 포함 (1~1000자)
 * - Swagger 문서화 + ValidationPipe 검증용
 */
export class SendMessageDto {
  @ApiProperty({
    example: '어디서 먹을래?',
    description: '전송할 메시지 내용 (1~1000자)',
    minLength: 1,
    maxLength: 1000,
  })
  @IsString({ message: '메시지 내용은 문자열이어야 합니다.' })
  @Length(1, 1000, { message: '메시지 길이는 1~1000자여야 합니다.' })
  text!: string;
}
