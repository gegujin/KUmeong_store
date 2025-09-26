import { Injectable, Logger } from '@nestjs/common';
import { MailerService } from '@nestjs-modules/mailer';

@Injectable()
export class UniversityEmailService {
  private readonly logger = new Logger(UniversityEmailService.name);

  constructor(private readonly mailer: MailerService) {}

  async sendVerificationCode(email: string, code: string, ttlSec: number) {
    const ttlMin = Math.max(1, Math.floor(ttlSec / 60));
    try {
      await this.mailer.sendMail({
        to: email,
        subject: '[KU멍가게] 학교 이메일 인증코드',
        template: 'verify-code', // templates/mail/verify-code.hbs
        context: { code, ttlMin, email },
      });
      this.logger.log(`메일 발송 성공: ${email}`);
    } catch (e: any) {
      this.logger.error(`메일 발송 실패: ${email} / ${e?.message ?? e}`);
      throw e; // 컨트롤러에서 DEV/PROD 분기 처리
    }
  }
}
