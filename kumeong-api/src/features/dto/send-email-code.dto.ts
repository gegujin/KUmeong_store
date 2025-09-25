import { IsEmail, IsNotEmpty, Matches } from 'class-validator';

export class SendEmailCodeDto {
  @IsNotEmpty()
  @IsEmail({}, { message: '올바른 이메일 형식이 아닙니다.' })
  // *.ac.kr 제한(대학 이메일) — 필요 시 더 촘촘히 정규식 개선 가능
  @Matches(/@.+\.ac\.kr$/i, { message: '대학교 이메일(@*.ac.kr)만 허용됩니다.' })
  email!: string;
}
