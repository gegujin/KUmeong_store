// src/modules/auth/dto/login.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength, MaxLength } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'student@kku.ac.kr' })
  @IsEmail()
  email!: string;

  @ApiProperty({
    example: '1234',
    description: '비밀번호 (영문/숫자/특수문자 조합 제한 없음)',
    minLength: 4,
    maxLength: 128,
  })
  @IsString()
  @MinLength(4)
  @MaxLength(128)
  password!: string;
}
