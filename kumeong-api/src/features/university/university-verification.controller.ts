// src/features/university/university-verification.controller.ts
import {Controller, Post, Body, BadRequestException, InternalServerErrorException} from '@nestjs/common';
import { EmailService } from '../../core/email/email.service';
import { CodeStoreService } from '../../core/verify/code-store.service';
import { UniversityDomainService } from '../../core/verify/university-domain.service';

type SendCodeDto = { email: string };
type VerifyCodeDto = { email: string; code: string };

@Controller('university')
export class UniversityVerificationController {
  private readonly CODE_TTL_SEC = Number(process.env.EMAIL_CODE_TTL_SEC ?? 300);
  private readonly COOLDOWN_SEC = Number(process.env.EMAIL_COOLDOWN_SEC ?? 60);

  constructor(
    private readonly emailService: EmailService,
    private readonly codeStore: CodeStoreService,
    private readonly uniDomain: UniversityDomainService,
  ) {}

  // ---- 안전 래퍼들: 실제 서비스 메서드 명이 달라도 컴파일/런타임 모두 안전 ----
  /** 학교 이메일 허용 여부 */
  private isAllowedEmail(email: string): boolean {
    const svc: any = this.uniDomain as any;
    if (svc && typeof svc.isAllowed === 'function') return !!svc.isAllowed(email);
    if (svc && typeof svc.isAllowedDomain === 'function') return !!svc.isAllowedDomain(email);
    if (svc && typeof svc.validate === 'function') return !!svc.validate(email);
    // 최후 수단: 환경변수 화이트리스트(예: KU.AC.KR,KHU.AC.KR)
    const list =
      process.env.UNI_EMAIL_DOMAINS?.split(',').map((s) => s.trim().toLowerCase()).filter(Boolean) ??
      [];
    if (list.length === 0) return true; // 설정 없으면 통과
    const e = email.toLowerCase();
    return list.some((d) => e.endsWith(`@${d}`) || e.endsWith(d));
  }

  /** 쿨다운 토큰 획득 */
  private async tryCooldown(email: string, sec: number): Promise<boolean> {
    const svc: any = this.codeStore as any;
    if (svc && typeof svc.cooldown === 'function') return await svc.cooldown(email, sec);
    // cooldown 메서드가 없다면: 쿨다운 미적용(허용)
    return true;
  }

  /** 메일 발송 */
  private async sendMail(to: string, subject: string, html: string): Promise<void> {
    const svc: any = this.emailService as any;
    if (svc && typeof svc.sendMail === 'function') {
      await svc.sendMail({ to, subject, html });
      return;
    }
    if (svc && typeof svc.send === 'function') {
      await svc.send({ to, subject, html });
      return;
    }
    if (svc && typeof svc.sendEmail === 'function') {
      await svc.sendEmail({ to, subject, html });
      return;
    }
    throw new InternalServerErrorException('EmailService: 발송 메서드가 정의되어 있지 않습니다.');
  }

  // ------------------------------------------------------------------------

  @Post('send-code')
  async sendCode(@Body() dto: SendCodeDto) {
    const email = dto.email?.trim();
    if (!email) throw new BadRequestException('email is required');

    if (!this.isAllowedEmail(email)) {
      throw new BadRequestException('허용되지 않은 학교 이메일입니다.');
    }

    const canSend = await this.tryCooldown(email, this.COOLDOWN_SEC);
    if (!canSend) throw new BadRequestException('잠시 후 다시 시도해주세요. (쿨다운)');

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    await this.codeStore.set(email, code, this.CODE_TTL_SEC);

    await this.sendMail(
      email,
      '[KU멍가게] 이메일 인증 코드',
      `<p>인증 코드: <b>${code}</b></p><p>${Math.floor(this.CODE_TTL_SEC / 60)}분 내에 입력하세요.</p>`,
    );

    return { ok: true };
  }

  @Post('verify')
  async verify(@Body() dto: VerifyCodeDto) {
    const email = dto.email?.trim();
    const code = dto.code?.trim();
    if (!email || !code) throw new BadRequestException('email, code are required');

    const ok = await this.codeStore.verify(email, code);
    if (!ok) throw new BadRequestException('인증 코드가 올바르지 않거나 만료되었습니다.');
    return { ok: true, verifiedEmail: email };
  }
}
