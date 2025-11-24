// dto/send-email-code.dto.ts
import { IsEmail, IsNotEmpty } from 'class-validator';
import { Transform } from 'class-transformer';

export class SendEmailCodeDto {
  @IsNotEmpty()
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsEmail({}, { message: '올바른 이메일 형식이 아닙니다.' })
  email!: string;
}
