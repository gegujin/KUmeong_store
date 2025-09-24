// src/modules/auth/dto/register.dto.ts
import { IsEmail, IsString, MinLength, MaxLength, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';

export class RegisterDto {
  @ApiProperty({
    example: 'student@kku.ac.kr',
    format: 'email',
    description: '로그인 이메일',
    required: true,
  })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim().toLowerCase() : value))
  @IsEmail()
  @MaxLength(320)
  email!: string;

  @ApiProperty({
    example: 'KKU Student',
    maxLength: 100,
    description: '표시될 이름',
    required: true,
  })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value))
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name!: string;

  @ApiProperty({
    example: '1234',
    minLength: 4,
    maxLength: 72, // bcrypt 권장 상한
    writeOnly: true,
    description: '4자 이상 비밀번호',
    required: true,
  })
  @IsString()
  @MinLength(4)
  @MaxLength(72)
  // 규정 강화 시:
  // @Matches(/^(?=.*[A-Za-z])(?=.*\d).{8,}$/, { message: '영문+숫자 조합 8자 이상' })
  password!: string;
}
