import { Module } from '@nestjs/common';
import { MailerModule } from '@nestjs-modules/mailer';
import { HandlebarsAdapter } from '@nestjs-modules/mailer/dist/adapters/handlebars.adapter';
import { join } from 'path';

@Module({
  imports: [
    MailerModule.forRootAsync({
      useFactory: () => ({
        transport: {
          host: process.env.MAIL_HOST ?? 'smtp.naver.com',
          port: Number(process.env.MAIL_PORT ?? 465),
          secure: String(process.env.MAIL_SECURE ?? 'true') === 'true', // 465는 보통 true
          auth: {
            user: process.env.MAIL_USER,
            pass: process.env.MAIL_PASS, // ← 네이버 앱 비밀번호
          },
          // 안정화 옵션 (네이버는 aggressive)
          pool: true,
          maxConnections: 2,
          maxMessages: 50,
          // 타임아웃/재시도 여지
          socketTimeout: 15000,
          connectionTimeout: 15000,
        },
        defaults: {
          from: process.env.MAIL_FROM || `"KU멍가게" <${process.env.MAIL_USER}>`,
        },
        template: {
          dir: join(process.cwd(), 'kumeong-api', 'templates', 'mail'),
          adapter: new HandlebarsAdapter(),
          options: { strict: false },
        },
        options: {
          partials: { dir: join(process.cwd(), 'kumeong-api', 'templates', 'mail', 'partials') },
        },
      }),
    }),
  ],
})
export class AppMailerModule {}
