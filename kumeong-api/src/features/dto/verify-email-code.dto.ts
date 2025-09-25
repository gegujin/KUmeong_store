import { IsEmail, IsNotEmpty, Matches, Length } from 'class-validator';

export class VerifyEmailCodeDto {
  @IsNotEmpty()
  @IsEmail()
  @Matches(/@.+\.ac\.kr$/i, { message: '대학교 이메일(@*.ac.kr)만 허용됩니다.' })
  email!: string;

  @IsNotEmpty()
  // 숫자 6자리 가정(차후 .env로 길이 조절 가능)
  @Length(6, 6, { message: '인증 코드는 6자리여야 합니다.' })
  @Matches(/^\d+$/, { message: '인증 코드는 숫자만 가능합니다.' })
  code!: string;
}
