// src/features/friends/dto/friend-requests.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsIn, IsOptional } from 'class-validator';
import { IsUUIDv1 } from '../../../common/validators/uuid';

// 컨트롤러 호환 타입
export type FriendRequestBox = 'incoming' | 'outgoing';

/**
 * 친구요청 생성 (대상 ID로)
 * - 모든 식별자는 UUIDv1 고정
 */
export class CreateFriendRequestDto {
  @ApiProperty({ description: '요청 대상 사용자 ID (UUIDv1)' })
  @IsUUIDv1({ message: 'toUserId는 UUIDv1 형식이어야 합니다.' })
  toUserId!: string;
}

/**
 * 친구요청 생성 (이메일로)
 * - 이메일 자체는 포맷만 검증, ID는 서비스에서 v1로 조회/사용
 */
export class CreateByEmailDto {
  @ApiProperty({ description: '요청 대상 사용자 이메일' })
  @IsEmail({}, { message: '유효한 이메일 형식이 아닙니다.' })
  email!: string;
}

/**
 * 친구요청 상태 변경
 * - 액션만 검증 (id는 Path DTO로 v1 검증)
 */
export class UpdateFriendRequestDto {
  @ApiProperty({ enum: ['accept', 'reject', 'cancel'] as const })
  @IsIn(['accept', 'reject', 'cancel'], {
    message: "action은 'accept' | 'reject' | 'cancel' 중 하나여야 합니다.",
  })
  action!: 'accept' | 'reject' | 'cancel';

  @IsOptional()
  note?: string;
}

/**
 * Path Param: 요청 ID (UUIDv1 강제)
 */
export class FriendRequestIdParamDto {
  @ApiProperty({ description: '친구요청 ID (UUIDv1)' })
  @IsUUIDv1({ message: 'id는 UUIDv1 형식이어야 합니다.' })
  id!: string;
}

/**
 * Query Param: box (incoming/outgoing)
 */
export class FriendRequestBoxQueryDto {
  @ApiProperty({ enum: ['incoming', 'outgoing'] as const, required: false, default: 'incoming' })
  @IsIn(['incoming', 'outgoing'], {
    message: "box는 'incoming' | 'outgoing' 중 하나여야 합니다.",
  })
  box: FriendRequestBox = 'incoming';
}
