// dto/send-email-code.dto.ts
import { IsEmail, IsNotEmpty, Matches } from 'class-validator';
import { Transform } from 'class-transformer';

const AC_KR_DOMAIN = /@([a-z0-9-]+\.)*ac\.kr$/i;

export class SendEmailCodeDto {
  @IsNotEmpty()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsEmail({}, { message: '올바른 이메일 형식이 아닙니다.' })
  @Matches(AC_KR_DOMAIN, { message: '대학교 이메일(@*.ac.kr)만 허용됩니다.' })
  email!: string;
}
