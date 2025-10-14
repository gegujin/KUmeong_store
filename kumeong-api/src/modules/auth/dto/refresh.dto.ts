// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\auth\dto\refresh.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length } from 'class-validator';

export class RefreshDto {
  @ApiProperty({
    description: '리프레시 토큰',
    example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  })
  @IsString()
  @Length(20) // 필요 시 최소 길이 조정
  refreshToken!: string; // definite assignment로 TS2564 해소
}
