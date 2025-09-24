// src/features/university/university-verification.controller.ts
import { Body, Controller, Post, BadRequestException } from '@nestjs/common';
import { EmailService } from '@/core/email/email.service';
import { CodeStoreService } from '@/core/verify/code-store.service';
import { UniversityDomainService } from '@/core/verify/university-domain.service';
import { StartSchema, VerifySchema } from './verification.dto';

@Controller('auth/univ')
export class UniversityVerificationController {
  constructor(
    private readonly email: EmailService,
    private readonly codes: CodeStoreService,
    private readonly univ: UniversityDomainService,
  ) {}

  @Post('start')
  async start(@Body() body: unknown) {
    const { email, univName } = StartSchema.parse(body);
    const ok = await this.univ.isUniversityEmail(email, univName);
    if (!ok.ok) throw new BadRequestException(`UNIV_EMAIL_REJECTED:${ok.reason}`);

    // 쿨다운
    const cooldownSec = Number(process.env.UNIV_VERIFY_COOLDOWN_SEC || 60);
    const allow = await this.codes.cooldown(email, cooldownSec);
    if (!allow) throw new BadRequestException('TOO_FREQUENT');

    // 코드 생성 & 저장
    const ttl = Number(process.env.UNIV_VERIFY_CODE_TTL_SEC || 300);
    const code = (Math.floor(100000 + Math.random() * 900000)).toString(); // 6자리
    await this.codes.set(email, code, ttl);

    await this.email.sendVerificationCode(email, code);
    return { ok: true, ttl };
  }

  @Post('verify')
  async verify(@Body() body: unknown) {
    const { email, code } = VerifySchema.parse(body);
    const ok = await this.codes.verify(email, code);
    if (!ok) throw new BadRequestException('INVALID_OR_EXPIRED_CODE');

    // TODO: DB에 인증 플래그 저장 (예: users.universityVerifiedAt, universityEmail, universityName)
    // await this.users.markUniversityVerified(userId, { email, universityName });

    return { ok: true, universityVerified: true };
  }
}
