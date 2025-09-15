import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EmailVerification } from '../entities/email-verification.entity';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import { MailerService } from '@nestjs-modules/mailer';
import { User } from '../../users/entities/user.entity'; // ← Users 존재 확인용

type Purpose = 'register' | 'reset' | 'login';

@Injectable()
export class EmailVerificationService {
  private readonly ttlSec: number;
  private readonly cooldownSec: number;
  private readonly maxAttempts: number;

  constructor(
    @InjectRepository(EmailVerification)
    private readonly repo: Repository<EmailVerification>,
    @InjectRepository(User)
    private readonly users: Repository<User>, // ← 열거 방지에 필요
    private readonly mailer: MailerService,
    private readonly cfg: ConfigService,
  ) {
    this.ttlSec = Number(this.cfg.get('EMAIL_CODE_TTL_SEC') ?? 300);
    this.cooldownSec = Number(this.cfg.get('EMAIL_COOLDOWN_SEC') ?? 60);
    this.maxAttempts = Number(this.cfg.get('EMAIL_MAX_ATTEMPTS') ?? 5);
  }

  private hash(code: string) {
    return crypto.createHash('sha256').update(code).digest('hex');
  }

  private genCode(): string {
    return String(Math.floor(Math.random() * 1_000_000)).padStart(6, '0');
  }

  /**
   * 열거 방지 정책:
   * - purpose === 'reset' | 'login' 인 경우, Users에 없으면
   *   👉 실제 메일 발송 및 EmailVerification 저장 없이 "성공" 응답을 반환.
   * - purpose === 'register'(기본) 인 경우, 항상 발송 플로우 진행.
   */
  async send(emailRaw: string, purpose: Purpose = 'register') {
    const email = emailRaw.trim().toLowerCase();
    if (!/^[a-zA-Z0-9._%+-]+@kku\.ac\.kr$/i.test(email)) {
      throw new BadRequestException('@kku.ac.kr 이메일만 사용할 수 있습니다.');
    }

    // 🔒 열거 방지: reset/login에서는 "존재 사용자"에게만 실제 발송
    if (purpose === 'reset' || purpose === 'login') {
      const user = await this.users.findOne({ where: { email } });
      if (!user) {
        // 존재하지 않는 이메일 → 조용히 성공 반환 (발송/레코드 생성 X)
        // 타이밍 유사화를 위해 미세 지연을 주고 싶다면 아래 주석 해제
        // await new Promise((r) => setTimeout(r, 150 + Math.random() * 150));
        return { ok: true, data: { ttlSec: this.ttlSec } };
      }
    }

    const now = new Date();
    const existing = await this.repo.findOne({
      where: { email },
      order: { createdAt: 'DESC' },
    });

    // 재전송 쿨다운
    if (existing?.lastSentAt) {
      const diff = (now.getTime() - new Date(existing.lastSentAt).getTime()) / 1000;
      if (diff < this.cooldownSec) {
        throw new BadRequestException(
          `잠시 후 다시 시도해 주세요. (${Math.ceil(this.cooldownSec - diff)}s)`,
        );
      }
    }

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
    await this.mailer.sendMail({
      to: email,
      from,
      subject: '[KU멍가게] 이메일 인증번호',
      text: `인증번호: ${code}\n유효시간: ${Math.floor(this.ttlSec / 60)}분`,
      html: `<div style="font-family:system-ui;max-width:480px;margin:24px auto;padding:16px;border:1px solid #eee;border-radius:12px">
        <h2>[KU멍가게] 이메일 인증번호</h2>
        <p>아래 인증번호를 입력해 주세요.</p>
        <div style="font-size:28px;font-weight:700;letter-spacing:6px;margin:16px 0">${code}</div>
        <p style="color:#666">유효시간: ${Math.floor(this.ttlSec / 60)}분</p>
        <p style="color:#999;font-size:12px">스팸함/프로모션함도 확인해 주세요.</p>
      </div>`,
    });

    if (this.cfg.get('NODE_ENV') !== 'production') {
      // eslint-disable-next-line no-console
      console.log(`[DEV] Email code for ${email}: ${code}`);
    }

    return { ok: true, data: { ttlSec: this.ttlSec } };
  }

  async verify(emailRaw: string, codeRaw: string) {
    const email = emailRaw.trim().toLowerCase();
    const code = codeRaw.trim();

    const rec = await this.repo.findOne({
      where: { email },
      order: { createdAt: 'DESC' },
    });
    if (!rec) throw new BadRequestException('인증 요청을 먼저 진행해 주세요.');

    const now = new Date();
    if (rec.usedAt) throw new BadRequestException('이미 사용된 코드입니다. 다시 요청해 주세요.');
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
}
