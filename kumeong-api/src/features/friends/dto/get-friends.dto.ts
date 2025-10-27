import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class GetFriendsQueryDto {
  @ApiPropertyOptional({
    description: '커서(이전 페이지 마지막 friendedAt, ISO-8601)',
    example: '2025-10-16T02:43:26.000Z',
  })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({
    description: '페이지 크기(두 갈래당 perSide, 최종 LIMIT도 동일)',
    default: 50,
    minimum: 1,
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  take?: number;
}
