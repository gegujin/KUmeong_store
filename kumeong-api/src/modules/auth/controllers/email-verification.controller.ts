import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { EmailVerificationService } from '../services/email-verification.service';
import { SendEmailCodeDto } from '../../auth/dto/send-email-code.dto';
import { VerifyEmailCodeDto } from '../../auth/dto/verify-email-code.dto';
import { ApiOperation, ApiTags } from '@nestjs/swagger';

@ApiTags('Auth')
@Controller({ path: 'auth/email', version: '1' })
export class EmailVerificationController {
  constructor(private readonly svc: EmailVerificationService) {}

  @Post('send-code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '인증코드 발송 (열거 방지 지원)' })
  sendCode(@Body() dto: SendEmailCodeDto) {
    // purpose 기본값은 서비스에서 'register'로 처리
    return this.svc.send(dto.email, dto.purpose);
  }

  @Post('verify-code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '인증코드 검증' })
  verify(@Body() dto: VerifyEmailCodeDto) {
    return this.svc.verify(dto.email, dto.code);
  }
}
