// kumeong-api/src/features/university/university-verification.controller.ts
import { Body, Controller, Headers, HttpCode, HttpStatus, Post, BadRequestException } from '@nestjs/common';
import { SendEmailCodeDto } from '../dto/send-email-code.dto';
import { VerifyEmailCodeDto } from '../dto/verify-email-code.dto';
import { CodeStoreService } from '../../core/verify/code-store.service';
import { UniversityDomainService } from '../../core/verify/university-domain.service';
import { UsersService } from '../../modules/users/users.service';
import { JwtService } from '@nestjs/jwt';
import { UniversityVerificationService } from './university-verification.service';

// ✅ 프로덕션 여부
const isProd = process.env.NODE_ENV === 'production';

/**
 * Base path: /university/email
 * - POST /university/email/send
 * - POST /university/email/verify
 * - POST /university/email/dev/peek   (DEV 전용)
 */
@Controller('university/email')
export class UniversityVerificationController {
  constructor(
    private readonly codeStore: CodeStoreService,
    private readonly domainSvc: UniversityDomainService,
    private readonly usersService: UsersService,
    private readonly jwt: JwtService,
    // ✅ 병합 정책/메일발송은 서비스로 위임
    private readonly verification: UniversityVerificationService,
  ) {}

  /** ① 인증코드 메일 전송 */
  @Post('send')
  @HttpCode(HttpStatus.OK)
  async send(@Body() dto: SendEmailCodeDto) {
    const email = String(dto.email ?? '').trim().toLowerCase();

    // *.ac.kr 확인 + 학교명 파싱(형식 검증)
    const { schoolName } = this.domainSvc.assertUniversityEmail(email);

    // 정책/쿨다운 확인 (UNIV_* → EMAIL_* → 기본값 순)
    const policy = await this.verification.getPolicy();

    // ⏱️ 쿨다운 체크 (남은 TTL이 있으면 차단)
    const cooldownKey = `univ:cooldown:${email}`;
    const still = await this.codeStore.ttl(cooldownKey); // 초 단위 TTL
    if (still > 0) {
      return { ok: false as const, reason: 'cooldown' as const, nextSendAt: new Date(Date.now() + still * 1000).toISOString() };
    }

    // 코드/TTL/학교명 발급 (코드 생성은 서비스 내부에서 정책 기반 길이로 수행)
    const { code, ttlSec } = await this.verification.issueCode(email);

    // DEV 로깅(응답에는 미포함)
    if (!isProd) {
      console.log(`[DEV][EMAIL-CODE] ${email} -> ${code} (ttl:${ttlSec}s)`);
    }

    // 실제 메일 발송 (FROM/제목/템플릿/TTL 안내는 서비스 내부에서 처리)
    try {
      await this.verification.sendMail(email, code);
    } catch (e) {
      if (isProd) {
        return { ok: false as const, reason: 'mail_send_failed' as const };
      }
      console.warn('[UniversityVerification] sendVerificationCode failed (dev ignored):', (e as any)?.message ?? e);
    }

    // ✅ 저장(코드 TTL + 쿨다운 TTL)
    await this.codeStore.set(email, code, ttlSec);
    await this.codeStore.set(cooldownKey, '1', policy.cooldownSec);

    const nextSendAt = new Date(Date.now() + policy.cooldownSec * 1000).toISOString();
    return { ok: true, ttlSec, nextSendAt, school: schoolName };
  }

  /** ② 인증코드 검증 */
  @Post('verify')
  @HttpCode(HttpStatus.OK)
  async verify(@Body() dto: VerifyEmailCodeDto) {
    const email = String(dto.email ?? '').trim().toLowerCase();

    // 코드 검증 (expired | mismatch | too_many | not_found 등 사유 포함)
    const result = this.codeStore.verify(email, dto.code);
    if (!result.ok) {
      return { ok: false as const, reason: result.reason };
    }

    // 이메일에서 학교명 재파싱
    const { schoolName } = this.domainSvc.assertUniversityEmail(email);

    // 사용자 프로필 갱신 (이미 있으면 already, 없으면 업데이트)
    const upd = await this.usersService.markUniversityVerifiedByEmail(email, schoolName);
    const profileUpdated = !!(upd as any)?.updated || !!(upd as any)?.already;

    // 학교인증 전용 토큰 (회원가입 단계 연계용)
    const univToken = await this.jwt.signAsync(
      { email, purpose: 'univ', school: schoolName },
      {
        secret: process.env.UNIV_TOKEN_SECRET ?? 'dev_univ_token_secret',
        expiresIn: process.env.UNIV_TOKEN_EXPIRES ?? '30m',
      },
    );

    if (!upd.ok) {
      return {
        ok: true as const,
        verified: true as const,
        profileUpdated: false as const,
        profileReason: (upd as any)?.reason,
        school: schoolName,
        univToken,
      };
    }

    return {
      ok: true as const,
      verified: true as const,
      profileUpdated,
      school: schoolName,
      profileSource: (upd as any)?.source ?? null,
      univToken,
    };
  }

  /** ③ (DEV 전용) 현재 유효한 코드 조회 */
  @Post('dev/peek')
  @HttpCode(HttpStatus.OK)
  async devPeek(
    @Body() body: { email: string },
    @Headers('x-dev-secret') devSecret: string,
  ) {
    if (isProd || process.env.ALLOW_CODE_PEEK !== 'true') {
      return { ok: false as const, reason: 'forbidden' as const, message: 'disabled_in_prod' };
    }

    const expected = process.env.DEV_CODE_PEEK_SECRET ?? '';
    if (!expected || devSecret !== expected) {
      return { ok: false as const, reason: 'unauthorized' as const, message: 'invalid_dev_secret' };
    }

    const email = String(body?.email ?? '').trim().toLowerCase();
    if (!email) return { ok: false as const, reason: 'bad_request' as const, message: 'email_required' };

    // 학교 이메일 규칙 검증(도메인/형식)
    try {
      this.domainSvc.assertUniversityEmail(email);
    } catch {
      return { ok: false as const, reason: 'bad_request' as const, message: 'invalid_univ_email' };
    }

    // CodeStore의 유효 코드 조회
    const peek = this.codeStore.peekActiveCode(email);
    if (!peek) {
      return { ok: false as const, reason: 'not_found' as const };
    }

    // DEV 전용이므로 코드 그대로 반환
    return { ok: true as const, code: peek.code, expiresAt: peek.expiresAt };
  }
}
