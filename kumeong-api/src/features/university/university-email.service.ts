// kumeong-api/src/features/university/university-email.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { MailerService } from '@nestjs-modules/mailer';

@Injectable()
export class UniversityEmailService {
  private readonly logger = new Logger(UniversityEmailService.name);
  constructor(private readonly mailer: MailerService) {}

  async sendVerificationCode(to: string, code: string, ttlSec: number) {
    const minutes = Math.max(1, Math.floor(ttlSec / 60));
    const subject = '[KU멍가게] 대학교 이메일 인증 코드';
    const html = `
      <div style="font-family:system-ui,Segoe UI,Apple SD Gothic Neo,sans-serif">
        <h2>대학교 이메일 인증</h2>
        <p>아래 인증 코드를 ${minutes}분 내에 입력해주세요.</p>
        <p style="font-size:20px;font-weight:700;letter-spacing:2px">${code}</p>
        <hr/>
        <small>본 메일은 발신 전용입니다.</small>
      </div>
    `;
    await this.mailer.sendMail({ to, subject, html });
    this.logger.log(`verification mail sent to ${to}`);
  }
}
