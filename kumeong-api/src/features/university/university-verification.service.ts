// src/features/university/university-verification.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { MailerService } from '@nestjs-modules/mailer';
import { ConfigService } from '@nestjs/config';
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

// 숫자 코드 생성 유틸
function generateNumericCode(len: number) {
  let s = '';
  for (let i = 0; i < len; i++) s += Math.floor(Math.random() * 10).toString();
  return s;
}

@Injectable()
export class UniversityVerificationService {
  private readonly logger = new Logger(UniversityVerificationService.name);

  constructor(
    private readonly mailer: MailerService,
    private readonly codes: CodeStoreService,
    private readonly domains: UniversityDomainService,
    private readonly cfg: ConfigService,
  ) {}

  /** ===========================
   *   Getter 구성
   * ============================ */
  private get codeLength(): number {
    const univLen = Number(this.cfg.get('UNIV_VERIFY_CODE_LENGTH'));
    if (!Number.isNaN(univLen) && univLen > 0) return univLen;

    const emailLen = Number(this.cfg.get('EMAIL_CODE_LENGTH', 6));
    return Number.isNaN(emailLen) || emailLen <= 0 ? 6 : emailLen;
  }

  private get codeTtlSec(): number {
    const u = Number(this.cfg.get('UNIV_VERIFY_CODE_TTL_SEC'));
    if (!Number.isNaN(u) && u > 0) return u;

    const e = Number(this.cfg.get('EMAIL_CODE_TTL_SEC', 300));
    return Number.isNaN(e) || e <= 0 ? 300 : e;
  }

  private get cooldownSec(): number {
    const u = Number(this.cfg.get('UNIV_VERIFY_COOLDOWN_SEC'));
    if (!Number.isNaN(u) && u > 0) return u;

    const e = Number(this.cfg.get('EMAIL_COOLDOWN_SEC', 60));
    return Number.isNaN(e) || e < 0 ? 60 : e;
  }

  private get maxAttempts(): number {
    const n = Number(this.cfg.get('EMAIL_MAX_ATTEMPTS', 5));
    return Number.isNaN(n) || n <= 0 ? 5 : n;
  }

  private get fromAddress(): string {
    return (
      this.cfg.get<string>('UNIV_VERIFY_FROM') ||
      this.cfg.get<string>('MAIL_FROM') ||
      '"KU멍가게" <no-reply@kumeong.local>'
    );
  }

  async getPolicy(): Promise<Policy> {
    return {
      ttlSec: this.codeTtlSec,
      cooldownSec: this.cooldownSec,
      maxAttempts: this.maxAttempts,
    };
  }

  /** ===========================
   *   인증코드 발급
   * ============================ */
  async issueCode(email: string): Promise<{
    code: string;
    nextSendAt: string | Date | null;
    ttlSec: number;
    schoolName: string;
  }> {
    const norm = String(email).trim().toLowerCase();
    const policy = await this.getPolicy();

    const { schoolName } = this.domains.assertUniversityEmail(norm);

    const can = this.codes.canSend(norm);
    const nextSendAt = can.ok
      ? new Date(Date.now() + policy.cooldownSec * 1000).toISOString()
      : can.nextSendAt ?? null;

    const code = generateNumericCode(this.codeLength);

    return { code, nextSendAt, ttlSec: policy.ttlSec, schoolName };
  }

  /** ===========================
   *   실제 메일 발송
   * ============================ */
  async sendMail(email: string, code: string) {
    this.logger.log(`[EMAIL-CODE] ${email} -> ${code}`);

    // Handlebars 템플릿 사용 가능 (university-code.hbs)
    await this.mailer.sendMail({
      to: email,
      from: this.fromAddress,
      subject: '[KU멍가게] 학교 이메일 인증코드',
      template: 'university-code',
      context: {
        code,
        ttlMin: Math.floor(this.codeTtlSec / 60),
        ttlSec: this.codeTtlSec,
      },

      // 템플릿 없이 텍스트만 쓸 수도 있음 (fallback)
      text: `학교 인증코드는 [${code}] 입니다. ${Math.floor(
        this.codeTtlSec / 60,
      )}분 이내에 입력해주세요.`,
    });
  }

  /** ===========================
   *   코드 검증
   * ============================ */
  async verifyCode(email: string, code: string): Promise<VerifyResult> {
    const norm = String(email).trim().toLowerCase();
    return this.codes.verify(norm, code);
  }
}
