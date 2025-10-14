import { Injectable } from '@nestjs/common';
import { MailerService } from '@nestjs-modules/mailer';

@Injectable()
export class MailTestService {
  constructor(private readonly mailer: MailerService) {}

  async sendSanity(to = 'dev@localhost') {
    await this.mailer.sendMail({
      to,
      subject: '[KU멍가게] Mail sanity test',
      text: 'This is a test email from KU멍가게.',
    });
    return { ok: true };
  }
}
