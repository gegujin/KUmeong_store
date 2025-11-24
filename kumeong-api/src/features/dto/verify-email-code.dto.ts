// dto/verify-email-code.dto.ts
import { IsEmail, IsNotEmpty, Matches } from 'class-validator';
import { Transform } from 'class-transformer';

export class VerifyEmailCodeDto {
  @IsNotEmpty()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsEmail({}, { message: '올바른 이메일 형식이 아닙니다.' })
  email!: string;

  @IsNotEmpty()
  @Matches(/^\d{6}$/, { message: '인증 코드는 6자리 숫자여야 합니다.' })
  code!: string;
}
