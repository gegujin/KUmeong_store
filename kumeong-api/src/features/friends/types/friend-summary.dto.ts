// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\types\friend-summary.dto.ts
import { ApiProperty } from '@nestjs/swagger';

export class FriendSummaryDto {
  // ✅ UUID(string) 기반으로 변경
  @ApiProperty({
    example: '11111111-1111-1111-1111-111111111111',
    description: '친구 사용자의 UUID',
  })
  userId!: string;

  @ApiProperty({ example: '김서진', description: '친구 이름 또는 닉네임' })
  displayName!: string;

  @ApiProperty({ example: 82, description: '신뢰 지수(0~100)' })
  trustScore!: number;

  @ApiProperty({ example: 12, description: '총 거래 횟수' })
  tradeCount!: number;

  @ApiProperty({
    example: ['전자제품', '도서'],
    description: '주로 거래한 상위 카테고리',
  })
  topItems!: string[];

  @ApiProperty({
    example: '2025-10-03T12:34:56.000Z',
    description: '최근 활동 시각 (ISO8601)',
  })
  lastActiveAt!: string;
}
