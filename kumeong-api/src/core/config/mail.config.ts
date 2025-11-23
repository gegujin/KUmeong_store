import { ConfigService } from '@nestjs/config';
import { MailerOptions } from '@nestjs-modules/mailer';
import { HandlebarsAdapter } from '@nestjs-modules/mailer/dist/adapters/handlebars.adapter';

export const mailConfigFactory = (cfg: ConfigService): MailerOptions => ({
  transport: {
    host: cfg.get('MAIL_HOST'),
    port: Number(cfg.get('MAIL_PORT')),
    secure: cfg.get('MAIL_SECURE') === 'true',
    auth: {
      user: cfg.get('MAIL_USER'),
      pass: cfg.get('MAIL_PASS'),
    },
  },
  defaults: {
    from: cfg.get('MAIL_FROM'),
  },
  template: {
    dir: __dirname + '/../../../templates',
    adapter: new HandlebarsAdapter(),
    options: { strict: true },
  },
});
