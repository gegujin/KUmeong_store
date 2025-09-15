import { IsEmail, IsIn, IsNotEmpty, IsOptional, Matches } from 'class-validator';

export class SendEmailCodeDto {
  @IsEmail()
  @IsNotEmpty()
  @Matches(/^[a-zA-Z0-9._%+-]+@kku\.ac\.kr$/i, { message: '@kku.ac.kr 이메일만 허용됩니다.' })
  email!: string;

  // 용도: 기본은 'register' (회원가입용), 'reset' | 'login'은 존재 열거 방지 모드
  @IsOptional()
  @IsIn(['register', 'reset', 'login'])
  purpose?: 'register' | 'reset' | 'login';
}
