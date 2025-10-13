// src/features/friends/dto/accept-request.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';

export class AcceptRequestDto {
  @ApiProperty({ required: false, description: '메모/사유(선택)' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}
