import { IsEmail, IsNotEmpty, Length, Matches } from 'class-validator';

export class VerifyEmailCodeDto {
  @IsEmail()
  @IsNotEmpty()
  email!: string;

  @IsNotEmpty()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code!: string;
}
