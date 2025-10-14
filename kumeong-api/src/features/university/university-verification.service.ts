// kumeong-api/src/features/university/university-verification.service.ts
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

// 숫자 코드 생성 유틸 (선행 0 허용)
function generateNumericCode(len: number) {
  let s = '';
  for (let i = 0; i < len; i++) s += Math.floor(Math.random() * 10).toString();
  return s;
}

@Injectable()
export class UniversityVerificationService {
  constructor(
    private readonly mailer: MailerService,
    private readonly codes: CodeStoreService,
    private readonly domains: UniversityDomainService,
    private readonly cfg: ConfigService, // ★ 추가: 환경변수 병합을 위해 주입
  ) {}

  /** 코드 길이: UNIV_VERIFY_CODE_LENGTH → EMAIL_CODE_LENGTH → 6 */
  private get codeLength(): number {
    // UNIV 전용 키가 있다면 우선 사용, 없으면 EMAIL_* 사용, 모두 없으면 6
    const univLen = Number(this.cfg.get('UNIV_VERIFY_CODE_LENGTH'));
    if (!Number.isNaN(univLen) && univLen > 0) return univLen;

    const emailLen = Number(this.cfg.get('EMAIL_CODE_LENGTH', 6));
    return Number.isNaN(emailLen) || emailLen <= 0 ? 6 : emailLen;
  }

  /** TTL: UNIV_VERIFY_CODE_TTL_SEC → EMAIL_CODE_TTL_SEC → 300 */
  private get codeTtlSec(): number {
    const u = Number(this.cfg.get('UNIV_VERIFY_CODE_TTL_SEC'));
    if (!Number.isNaN(u) && u > 0) return u;

    const e = Number(this.cfg.get('EMAIL_CODE_TTL_SEC', 300));
    return Number.isNaN(e) || e <= 0 ? 300 : e;
  }

  /** COOLDOWN: UNIV_VERIFY_COOLDOWN_SEC → EMAIL_COOLDOWN_SEC → 60 */
  private get cooldownSec(): number {
    const u = Number(this.cfg.get('UNIV_VERIFY_COOLDOWN_SEC'));
    if (!Number.isNaN(u) && u > 0) return u;

    const e = Number(this.cfg.get('EMAIL_COOLDOWN_SEC', 60));
    return Number.isNaN(e) || e < 0 ? 60 : e;
  }

  /** MAX ATTEMPTS: EMAIL_MAX_ATTEMPTS → 5 (UNIV_*가 별도로 없으므로 EMAIL_* 우선) */
  private get maxAttempts(): number {
    const n = Number(this.cfg.get('EMAIL_MAX_ATTEMPTS', 5));
    return Number.isNaN(n) || n <= 0 ? 5 : n;
  }

  /** FROM 주소: UNIV_VERIFY_FROM → MAIL_FROM → 기본값 */
  private get fromAddress(): string {
    return (
      this.cfg.get<string>('UNIV_VERIFY_FROM') ||
      this.cfg.get<string>('MAIL_FROM') ||
      '"KU멍가게" <no-reply@kumeong.local>'
    );
  }

  /** 환경/설정 기반 정책값 (컨트롤러/서비스 공용 사용) */
  async getPolicy(): Promise<Policy> {
    return {
      ttlSec: this.codeTtlSec,
      cooldownSec: this.cooldownSec,
      maxAttempts: this.maxAttempts,
    };
  }

  /**
   * 인증 코드 발급(저장/쿨다운 적용은 컨트롤러에서 수행)
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

    // *.ac.kr 확인 + 학교명 파싱
    const { schoolName } = this.domains.assertUniversityEmail(norm);

    // 쿨다운 정보 조회(저장은 컨트롤러에서 set() 호출 후 수행)
    const can = this.codes.canSend(norm);
    const nextSendAt = can.ok
      ? new Date(Date.now() + policy.cooldownSec * 1000).toISOString()
      : can.nextSendAt ?? null;

    // 코드 생성만 담당 (저장은 컨트롤러에서 메일 발송 성공 후 set)
    const code = generateNumericCode(this.codeLength);

    return { code, nextSendAt, ttlSec: policy.ttlSec, schoolName };
  }

  /**
   * 실제 메일 발송 (템플릿 사용)
   * - 컨트롤러에서 DEV/PROD 분기 처리하므로 여기서는 그대로 throw
   * * ⭐️ 기존 sendVerificationEmail 메서드를 sendMail로 이름 변경하여 TS2339 오류 해결
   */
  private readonly logger = new Logger(UniversityVerificationService.name);

  async sendMail(email: string, code: string) {
    // 컨트롤러에서 `ttlSec` 인자를 넘기더라도, 서비스 내부 `codeTtlSec`을 사용하므로 인자에서 제거
    this.logger.log(`[DEV][EMAIL-CODE] ${email} -> ${code} (ttl:${this.codeTtlSec}s)`);

    await this.mailer.sendMail({
      to: email,
      from: this.fromAddress, // from 주소를 설정값(getter)으로 변경
      subject: '[KU멍가게] 학교 이메일 인증코드',
      text: `학교 인증을 위한 인증코드는 [${code}] 입니다.\n${
        this.codeTtlSec / 60
      }분 이내에 입력해주세요.`, // TTL 설정값을 본문에 반영
    });
  }

  /**
   * 코드 검증
   * - 실패 사유(reason): 'expired' | 'mismatch' | 'too_many' | 'not_found'
   */
  async verifyCode(email: string, code: string): Promise<VerifyResult> {
    const norm = String(email || '').trim().toLowerCase();
    return this.codes.verify(norm, code);
  }
}