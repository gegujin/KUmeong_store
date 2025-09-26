// kumeong-api/src/features/university/university-verification.service.ts
import { Injectable } from '@nestjs/common';
import { MailerService } from '@nestjs-modules/mailer';
import { CodeStoreService } from '../../core/verify/code-store.service';
import { UniversityDomainService } from '../../core/verify/university-domain.service';

type VerifyReason = 'expired' | 'mismatch' | 'too_many' | 'not_found';
export interface VerifyResult {
  ok: boolean;
  reason?: VerifyReason;
}

export interface Policy {
  ttlSec: number;
  cooldownSec: number;
  maxAttempts: number;
}

const CODE_LENGTH = Number(process.env.EMAIL_CODE_LENGTH ?? 6);
function generateNumericCode(len = CODE_LENGTH) {
  let s = '';
  for (let i = 0; i < len; i++) s += Math.floor(Math.random() * 10).toString();
  return s; // 선행 0 허용
}

@Injectable()
export class UniversityVerificationService {
  constructor(
    private readonly mailer: MailerService,
    private readonly codes: CodeStoreService,
    private readonly domains: UniversityDomainService,
  ) {}

  /** 환경/설정 기반 정책값 */
  async getPolicy(): Promise<Policy> {
    return {
      ttlSec: Number(process.env.EMAIL_CODE_TTL_SEC ?? 300),
      cooldownSec: Number(process.env.EMAIL_COOLDOWN_SEC ?? 60),
      maxAttempts: Number(process.env.EMAIL_MAX_ATTEMPTS ?? 5),
    };
  }

  /**
   * 인증 코드 발급(저장/쿨다운 적용은 컨트롤러에서 수행)
   * - 실제 프로젝트 제공 메서드: assertUniversityEmail / canSend / getPolicy
   * - 여기서는 코드만 생성하고 nextSendAt/ttlSec/학교명을 돌려준다.
   */
  async issueCode(email: string): Promise<{
    code: string;
    nextSendAt: string | Date | null;
    ttlSec: number;
    schoolName: string;
  }> {
    const norm = String(email || '').trim().toLowerCase();
    const policy = await this.getPolicy();

    // *.ac.kr 확인 + 학교명 파싱 (레포에 존재하는 메서드)
    const { schoolName } = this.domains.assertUniversityEmail(norm);

    // 쿨다운 정보 조회(저장은 컨트롤러에서 set() 호출 후 수행)
    const can = this.codes.canSend(norm);
    const nextSendAt = can.ok
      ? new Date(Date.now() + policy.cooldownSec * 1000).toISOString()
      : can.nextSendAt ?? null;

    // 코드 생성만 담당 (저장은 컨트롤러에서 메일 발송 성공 후 set)
    const code = generateNumericCode();

    return { code, nextSendAt, ttlSec: policy.ttlSec, schoolName };
  }

  /**
   * 실제 메일 발송 (템플릿 사용)
   * - 컨트롤러에서 DEV/PROD 분기 처리하므로 여기서는 그대로 throw
   */
  async sendMail(email: string, code: string, ttlSec: number): Promise<void> {
    const norm = String(email || '').trim().toLowerCase();
    await this.mailer.sendMail({
      to: norm,
      subject: '[KU멍가게] 학교 이메일 인증코드',
      template: 'verify-code',
      context: { code, ttlMin: Math.floor(ttlSec / 60) },
    });
  }

  /**
   * 코드 검증
   * - 레포 제공 메서드 그대로 위임: codes.verify(email, code)
   * - 실패 시 사유(reason): 'expired' | 'mismatch' | 'too_many' | 'not_found'
   */
  async verifyCode(email: string, code: string): Promise<VerifyResult> {
    const norm = String(email || '').trim().toLowerCase();
    return this.codes.verify(norm, code);
  }
}
