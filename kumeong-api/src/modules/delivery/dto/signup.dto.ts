import { IsEmail, IsOptional, IsString, MaxLength } from 'class-validator';

export class SignupDto {
  @IsEmail()
  email!: string; // kku.ac.kr만 허용(서비스에서 검사)

  @IsString()
  @MaxLength(50)
  transport!: string; // '도보' | '자전거' | '오토바이' | '기타문자열'

  @IsOptional()
  @IsString()
  univToken?: string; // 선택: 학교인증 토큰(있으면 검증 로직에서 사용)
}
