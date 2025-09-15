import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { EmailVerificationService } from '../services/email-verification.service';
import { SendEmailCodeDto } from '../../auth/dto/send-email-code.dto';
import { VerifyEmailCodeDto } from '../../auth/dto/verify-email-code.dto';
import { ApiTags, ApiOperation } from '@nestjs/swagger';

@ApiTags('Auth')
@Controller({ path: 'auth/email', version: '1' })
export class EmailVerificationController {
  constructor(private readonly svc: EmailVerificationService) {}

  @Post('send-code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '이메일 인증코드 발송(@kku.ac.kr 전용)' })
  sendCode(@Body() dto: SendEmailCodeDto) {
    return this.svc.send(dto.email.trim().toLowerCase());
  }

  @Post('verify-code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '이메일 인증코드 검증' })
  verify(@Body() dto: VerifyEmailCodeDto) {
    return this.svc.verify(dto.email.trim().toLowerCase(), dto.code.trim());
  }
}
