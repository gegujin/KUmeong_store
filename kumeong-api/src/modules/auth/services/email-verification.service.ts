// src/modules/auth/services/email-verification.service.ts
import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan, IsNull } from 'typeorm';
import { EmailVerification } from '../entities/email-verification.entity';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailVerificationService {
  private readonly ttlSec = this.cfg.get<number>('EMAIL_CODE_TTL_SEC', 300);
  private readonly cooldownSec = this.cfg.get<number>('EMAIL_COOLDOWN_SEC', 60);
  private readonly maxAttempts = this.cfg.get<number>('EMAIL_MAX_ATTEMPTS', 5);

  // Nodemailer 트랜스포터
  private readonly tx: nodemailer.Transporter;

  constructor(
    @InjectRepository(EmailVerification)
    private readonly repo: Repository<EmailVerification>,
    private readonly cfg: ConfigService,
  ) {
    this.tx = nodemailer.createTransport({
      host: this.cfg.get<string>('SMTP_HOST'),
      port: Number(this.cfg.get('SMTP_PORT')),
      secure: this.cfg.get('SMTP_SECURE') === 'true' || this.cfg.get('SMTP_SECURE') === true,
      auth: { user: this.cfg.get('SMTP_USER'), pass: this.cfg.get('SMTP_PASS') },
    });
  }

  private ensureKku(email: string) {
    if (!/^[a-zA-Z0-9._%+-]+@kku\.ac\.kr$/i.test(email.trim())) {
      throw new BadRequestException('학교 이메일(@kku.ac.kr)만 사용할 수 있습니다.');
    }
  }

  private hash(code: string) {
    return crypto.createHash('sha256').update(code).digest('hex');
  }

  private genCode(): string {
    // 6자리 숫자 (000000~999999, 앞자리 0 유지)
    return String(Math.floor(Math.random() * 1_000_000)).padStart(6, '0');
  }

  /** (프로브 비활성 버전) 항상 'unknown' 반환 */
  private async probeExistence(_email: string): Promise<'unknown'> {
    return 'unknown';
  }

  async send(emailRaw: string) {
    const email = emailRaw.trim().toLowerCase();
    this.ensureKku(email);

    const now = new Date();
    const existing = await this.repo.findOne({
      where: { email },
      order: { createdAt: 'DESC' },
    });

    // 쿨다운 체크
    if (existing?.lastSentAt) {
      const diff = (now.getTime() - new Date(existing.lastSentAt).getTime()) / 1000;
      if (diff < this.cooldownSec) {
        const remain = Math.ceil(this.cooldownSec - diff);
        throw new BadRequestException(`잠시 후 다시 시도해 주세요. (${remain}s)`);
      }
    }

    // (프로브는 unknown으로만 기록)
    const probe = await this.probeExistence(email);

    // 코드 생성/저장
    const code = this.genCode();
    const rec = existing ?? this.repo.create({ email });
    rec.codeHash = this.hash(code);
    rec.expireAt = new Date(now.getTime() + this.ttlSec * 1000);
    rec.remainingAttempts = this.maxAttempts;
    rec.usedAt = null;
    rec.lastSentAt = now;
    await this.repo.save(rec);

    // 메일 발송
    const from = this.cfg.get<string>('MAIL_FROM') ?? 'no-reply@example.com';
    const subject = this.cfg.get<string>('MAIL_SUBJECT') ?? '[KU멍가게] 이메일 인증번호';
    await this.tx.sendMail({
      to: email,
      from,
      subject,
      text: `인증번호: ${code}\n유효시간: ${Math.floor(this.ttlSec / 60)}분\n타인에게 공유하지 마세요.`,
      html: `
        <div style="font-family:system-ui;max-width:480px;margin:24px auto;padding:16px;border:1px solid #eee;border-radius:12px">
          <h2>[KU멍가게] 이메일 인증번호</h2>
          <p style="font-size:16px">아래 인증번호를 앱/웹에 입력해 주세요.</p>
          <div style="font-size:28px;font-weight:700;letter-spacing:6px;margin:16px 0">${code}</div>
          <p style="color:#666">유효시간: ${Math.floor(this.ttlSec / 60)}분</p>
          <p style="color:#999;font-size:12px">본 메일이 본인 의도가 아니라면 무시하셔도 됩니다.</p>
        </div>
      `,
    });

    // 개발 편의: 콘솔에 코드 출력(운영에선 제거 권장)
    if (this.cfg.get('NODE_ENV') !== 'production') {
      // eslint-disable-next-line no-console
      console.log(`[DEV] Email code for ${email}: ${code}`);
    }

    return { ok: true, data: { ttlSec: this.ttlSec, probe } };
  }

  async verify(emailRaw: string, codeRaw: string) {
    const email = emailRaw.trim().toLowerCase();
    const code = codeRaw.trim();
    this.ensureKku(email);

    const now = new Date();
    const rec = await this.repo.findOne({
      where: { email },
      order: { createdAt: 'DESC' },
    });
    if (!rec) throw new BadRequestException('인증 요청을 먼저 진행해 주세요.');

    if (rec.usedAt) throw new BadRequestException('이미 사용된 코드입니다. 새로 요청해 주세요.');
    if (rec.expireAt.getTime() < now.getTime()) {
      throw new BadRequestException('코드가 만료되었습니다. 다시 요청해 주세요.');
    }
    if (rec.remainingAttempts <= 0) {
      throw new BadRequestException('시도 횟수를 초과했습니다. 다시 요청해 주세요.');
    }

    const ok = rec.codeHash === this.hash(code);
    if (!ok) {
      rec.remainingAttempts -= 1;
      await this.repo.save(rec);
      throw new BadRequestException(`코드가 일치하지 않습니다. (남은 시도: ${rec.remainingAttempts})`);
    }

    rec.usedAt = now;
    await this.repo.save(rec);
    return { ok: true, data: { emailVerified: true } };
  }

  /** 만료됐고 아직 사용되지 않은 레코드 정리(선택) */
  async prune(): Promise<void> {
    const now = new Date();
    await this.repo.delete({
      expireAt: LessThan(now),
      usedAt: IsNull(),
    });
  }
}
