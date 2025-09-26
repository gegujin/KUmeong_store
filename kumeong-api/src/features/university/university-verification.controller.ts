import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { SendEmailCodeDto } from '../dto/send-email-code.dto';
import { VerifyEmailCodeDto } from '../dto/verify-email-code.dto';
import { CodeStoreService } from '../../core/verify/code-store.service';
import { UniversityDomainService } from '../../core/verify/university-domain.service';
import { UniversityEmailService } from './university-email.service';
import { UsersService } from '../../modules/users/users.service'; // ✅ 경로 주의

const CODE_LENGTH = Number(process.env.EMAIL_CODE_LENGTH ?? 6);

function generateNumericCode(len = CODE_LENGTH) {
  let s = '';
  for (let i = 0; i < len; i++) s += Math.floor(Math.random() * 10).toString();
  return s; // 선행 0 허용
}

@Controller('university')
export class UniversityVerificationController {
  constructor(
    private readonly codeStore: CodeStoreService,
    private readonly domainSvc: UniversityDomainService,
    private readonly uniEmail: UniversityEmailService,
    private readonly usersService: UsersService,
  ) {}

  /** ① 인증코드 메일 전송 */
  @Post('email/send')
  @HttpCode(HttpStatus.OK)
  async send(@Body() dto: SendEmailCodeDto) {
    // *.ac.kr 확인 + 학교명 파싱
    const { schoolName } = this.domainSvc.assertUniversityEmail(dto.email);

    // 쿨다운 체크
    const policy = this.codeStore.getPolicy();
    const can = this.codeStore.canSend(dto.email);
    if (!can.ok) return { ok: false, reason: 'cooldown' as const, nextSendAt: can.nextSendAt };

    // 코드 생성 → 메일 발송(성공 시에만 저장)
    const code = generateNumericCode();
    try {
      await this.uniEmail.sendVerificationCode(dto.email, code, policy.ttlSec);
    } catch {
      return { ok: false, reason: 'mail_send_failed' as const };
    }

    // 저장(만료/시도횟수/마지막발송 갱신)
    this.codeStore.set(dto.email, code);

    const nextSendAt = new Date(Date.now() + policy.cooldownSec * 1000).toISOString();
    return { ok: true, ttlSec: policy.ttlSec, nextSendAt, school: schoolName };
  }

  /** ② 인증코드 검증 */
  @Post('email/verify')
  @HttpCode(HttpStatus.OK)
  async verify(@Body() dto: VerifyEmailCodeDto) {
    // 코드 검증
    const result = this.codeStore.verify(dto.email, dto.code);
    if (!result.ok) return { ok: false, reason: result.reason };

    // 이메일에서 학교명 재파싱(도메인은 동일하므로 안전)
    const { schoolName } = this.domainSvc.assertUniversityEmail(dto.email);

    // 사용자 프로필 갱신
    const updated = await this.usersService.markUniversityVerifiedByEmail(dto.email, schoolName);
    if (!updated.ok) {
      // 유저 미존재라면 인증은 true지만, 프로필 업뎃 실패 사유를 내려준다.
      return { ok: true, verified: true, profileUpdated: false, profileReason: updated.reason };
    }

    return { ok: true, verified: true, profileUpdated: true, school: schoolName };
  }
}