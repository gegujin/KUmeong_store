import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { SendEmailCodeDto } from '../dto/send-email-code.dto';
import { VerifyEmailCodeDto } from '../dto/verify-email-code.dto';

@Controller('university')
export class UniversityVerificationController {
  /**
   * ① 인증코드 메일 전송
   * - 지금은 스텁: 입력 검증만 통과하면 OK 형태의 가짜 응답
   * - 실제 메일 전송/쿨다운/TTL은 다음 단계에서 구현
   */
  @Post('email/send')
  @HttpCode(HttpStatus.OK)
  async send(@Body() dto: SendEmailCodeDto) {
    // TODO(next): domain 검증, 코드 생성/저장, SMTP 발송, 쿨다운 계산
    const ttlSec = 300; // .env EMAIL_CODE_TTL_SEC 사용할 예정
    const nextSendAt = new Date(Date.now() + 60 * 1000).toISOString(); // 쿨다운 60s 가정
    return { ok: true, ttlSec, nextSendAt };
  }

  /**
   * ② 인증코드 검증
   * - 지금은 스텁: 항상 실패/성공 중 택1의 목업 반환
   * - 다음 단계에서 실제 검증 로직 (TTL/시도횟수/불일치) 채움
   */
  @Post('email/verify')
  @HttpCode(HttpStatus.OK)
  async verify(@Body() dto: VerifyEmailCodeDto) {
    // TODO(next): 저장된 코드와 대조, 만료/불일치/시도초과 처리
    const verified = true; // 목업
    return verified
      ? { ok: true, verified: true }
      : { ok: false, reason: 'mismatch' as const };
  }
}
