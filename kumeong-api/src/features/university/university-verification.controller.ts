// kumeong-api/src/features/university/university-verification.controller.ts
import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { SendEmailCodeDto } from '../dto/send-email-code.dto';
import { VerifyEmailCodeDto } from '../dto/verify-email-code.dto';
import { CodeStoreService } from '../../core/verify/code-store.service';
import { UniversityDomainService } from '../../core/verify/university-domain.service';
import { UniversityEmailService } from './university-email.service';
import { UsersService } from '../../modules/users/users.service';

const CODE_LENGTH = Number(process.env.EMAIL_CODE_LENGTH ?? 6);

function generateNumericCode(len = CODE_LENGTH) {
  let s = '';
  for (let i = 0; i < len; i++) s += Math.floor(Math.random() * 10).toString();
  return s; // 선행 0 허용
}

/**
 * Base path: /university/email
 * - POST /university/email/send
 * - POST /university/email/verify
 */
@Controller('university/email')
export class UniversityVerificationController {
  constructor(
    private readonly codeStore: CodeStoreService,
    private readonly domainSvc: UniversityDomainService,
    private readonly uniEmail: UniversityEmailService,
    private readonly usersService: UsersService,
  ) {}

  /** ① 인증코드 메일 전송 */
  @Post('send')
  @HttpCode(HttpStatus.OK)
  async send(@Body() dto: SendEmailCodeDto) {
    // *.ac.kr 확인 + 학교명 파싱
    const { schoolName } = this.domainSvc.assertUniversityEmail(dto.email);

    // 정책/쿨다운 확인
    const policy = this.codeStore.getPolicy(); // { ttlSec, cooldownSec, maxAttempts, ... }
    const can = this.codeStore.canSend(dto.email);
    if (!can.ok) {
      return { ok: false as const, reason: 'cooldown' as const, nextSendAt: can.nextSendAt };
    }

    // 코드 생성
    const code = generateNumericCode();
    const isProd = process.env.NODE_ENV === 'production';

    // DEV 전용 콘솔 로그
    if (!isProd) {
      console.log(`[DEV][EMAIL-CODE] ${dto.email} -> ${code} (ttl:${policy.ttlSec}s)`);
    }

    // 실제 메일 발송(DEV에서는 실패해도 진행)
    try {
      await this.uniEmail.sendVerificationCode(dto.email, code, policy.ttlSec);
    } catch (e) {
      if (isProd) {
        return { ok: false as const, reason: 'mail_send_failed' as const };
      }
      console.warn('[UniversityVerification] sendVerificationCode failed (dev ignored):', (e as any)?.message ?? e);
    }

    // 저장(만료/시도횟수/마지막발송 갱신)
    this.codeStore.set(dto.email, code);

    const nextSendAt = new Date(Date.now() + policy.cooldownSec * 1000).toISOString();
    const res: any = { ok: true, ttlSec: policy.ttlSec, nextSendAt, school: schoolName };
    if (!isProd) res.devCode = code; // ✅ DEV 응답에 코드 포함
    return res;
  }

  /** ② 인증코드 검증 */
  @Post('verify')
  @HttpCode(HttpStatus.OK)
  async verify(@Body() dto: VerifyEmailCodeDto) {
    // 코드 검증 (expired | mismatch | too_many | not_found 등 사유 포함)
    const result = this.codeStore.verify(dto.email, dto.code);
    if (!result.ok) {
      return { ok: false as const, reason: result.reason };
    }

    // 이메일에서 학교명 재파싱
    const { schoolName } = this.domainSvc.assertUniversityEmail(dto.email);

    // 사용자 프로필 갱신 (메모리/DB 모두 커버)
    const upd = await this.usersService.markUniversityVerifiedByEmail(dto.email, schoolName);
    if (!upd.ok) {
      // 유저 미존재 등: 인증 자체는 통과했지만 프로필 반영 실패 사유 전달
      return { ok: true as const, verified: true as const, profileUpdated: false as const, profileReason: upd.reason, school: schoolName };
    }

    return {
      ok: true as const,
      verified: true as const,
      profileUpdated: !!(upd as any)?.updated || !!(upd as any)?.already,
      school: schoolName,
      profileSource: (upd as any)?.source ?? null,
    };
  }
}
