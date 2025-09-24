// src/modules/auth/dto/login.dto.ts
import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength, MaxLength } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'student@kku.ac.kr' })
  @IsEmail()
  email!: string;

  @ApiProperty({ example: '1234', minLength: 4 })
  @IsString()
  @MinLength(4)
  @MaxLength(64)
  password!: string;
}
