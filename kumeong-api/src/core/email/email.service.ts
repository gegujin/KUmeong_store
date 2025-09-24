// src/core/email/email.service.ts
import { Injectable } from '@nestjs/common';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailService {
  private transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST!,
    port: Number(process.env.SMTP_PORT!),
    secure: process.env.SMTP_SECURE === 'true',
    auth: { user: process.env.SMTP_USER!, pass: process.env.SMTP_PASS! },
  });

  async sendVerificationCode(to: string, code: string) {
    await this.transporter.sendMail({
      from: process.env.UNIV_VERIFY_FROM || process.env.MAIL_FROM,
      to,
      subject: 'KU멍가게 대학 이메일 인증 코드',
      text: `인증 코드: ${code} (유효시간 ${process.env.UNIV_VERIFY_CODE_TTL_SEC || 300}초)`,
      html: `<p>인증 코드: <b>${code}</b></p><p>유효시간: ${process.env.UNIV_VERIFY_CODE_TTL_SEC || 300}초</p>`,
    });
  }
}
