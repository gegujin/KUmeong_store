// src/features/friends/dto/friend-request-by-email.dto.ts
import { IsEmail, IsNotEmpty, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';

export class FriendRequestByEmailDto {
  @ApiProperty({
    example: 'user1@kku.ac.kr',
    description: '상대방 이메일 (대학교 이메일만 허용)',
  })
  @Transform(({ value, obj }) => {
    // { email } 또는 { toEmail } 둘 다 지원
    const v = (value ?? obj?.toEmail ?? '').trim().toLowerCase();
    return v;
  })
  @IsNotEmpty({ message: '이메일은 필수 입력입니다.' })
  @IsEmail({}, { message: '유효한 이메일 주소가 아닙니다.' })
  @Matches(/@([a-z0-9-]+\.)*ac\.kr$/i, {
    message: '대학교 이메일(@*.ac.kr)만 허용됩니다.',
  })
  email!: string;
}
