// src/core/config/mail.config.ts
import { ConfigService } from '@nestjs/config';
import { Logger } from '@nestjs/common';

type Transport = {
  host: string;
  port: number;
  secure?: boolean;
  auth?: { user: string; pass: string };
  tls?: { rejectUnauthorized?: boolean };
};

type MailerRootOptions = {
  transport: Transport;
  defaults?: { from?: string };
};

const log = new Logger('MailConfig');

function toBool(v: any, def = false) {
  if (v === undefined || v === null || v === '') return def;
  const s = String(v).toLowerCase().trim();
  return ['1', 'true', 'yes', 'y', 'on'].includes(s);
}

export function mailConfigFactory(cfg: ConfigService): MailerRootOptions {
  const NODE_ENV = (cfg.get<string>('NODE_ENV') || 'development').toLowerCase() as
    | 'development' | 'staging' | 'production';
  const MAIL_PROVIDER = (cfg.get<string>('MAIL_PROVIDER') || 'auto').toLowerCase() as
    | 'auto' | 'mailpit' | 'mailtrap' | 'smtp';

  // 0) 공통 from
  const MAIL_FROM =
    cfg.get<string>('MAIL_FROM') ??
    'KU멍가게 <no-reply@kumeong.local>';
  const UNIV_VERIFY_FROM =
    cfg.get<string>('UNIV_VERIFY_FROM') ?? MAIL_FROM;

  // 1) 최우선(override): MAIL_HOST/PORT 직접 명시 → 어떤 환경에서도 즉시 적용
  const directHost = cfg.get<string>('MAIL_HOST');
  const directPort = cfg.get<number>('MAIL_PORT');
  if (directHost && directPort) {
    const directSecure = toBool(cfg.get('MAIL_SECURE'), false);
    const directUser = cfg.get<string>('MAIL_USER') || undefined;
    const directPass = cfg.get<string>('MAIL_PASS') || undefined;

    if ((directUser && !directPass) || (!directUser && directPass)) {
      log.warn('MAIL_USER 또는 MAIL_PASS 중 하나만 설정됨. auth를 사용하지 않습니다.');
    }

    log.log(`mail: using direct MAIL_HOST/PORT (${directHost}:${directPort})`);
    return {
      transport: {
        host: directHost,
        port: Number(directPort),
        secure: directSecure,
        ...(directUser && directPass
          ? { auth: { user: directUser, pass: directPass } }
          : {}),
        tls: { rejectUnauthorized: false }, // Mailpit/Mailtrap에도 안전
      },
      defaults: { from: MAIL_FROM },
    };
  }

  // 2) PROVIDER 선택 (auto → NODE_ENV 매핑)
  const provider =
    MAIL_PROVIDER === 'auto'
      ? NODE_ENV === 'production'
        ? 'smtp'
        : NODE_ENV === 'staging'
          ? 'mailtrap'
          : 'mailpit'
      : MAIL_PROVIDER;

  // 3) provider별 구성 + 레거시 변수 호환(DEV_/STAGE_/PROD_)
  if (provider === 'mailpit') {
    // 개발용(로컬) — Mailpit
    const host =
      cfg.get<string>('DEV_MAIL_HOST') || '127.0.0.1';
    const port =
      Number(cfg.get<number>('DEV_MAIL_PORT') ?? 1025);
    const secure = toBool(cfg.get('DEV_MAIL_SECURE'), false);
    const user = cfg.get<string>('DEV_MAIL_USER') || undefined;
    const pass = cfg.get<string>('DEV_MAIL_PASS') || undefined;

    log.log(`mail: provider=mailpit (${host}:${port})`);
    return {
      transport: {
        host, port, secure,
        ...(user && pass ? { auth: { user, pass } } : {}),
        tls: { rejectUnauthorized: false },
      },
      defaults: { from: MAIL_FROM },
    };
  }

  if (provider === 'mailtrap') {
    // 스테이징(팀 공유) — Mailtrap
    const host =
      cfg.get<string>('STAGE_MAIL_HOST') || 'smtp.mailtrap.io';
    const port =
      Number(cfg.get<number>('STAGE_MAIL_PORT') ?? 2525);
    const secure = toBool(cfg.get('STAGE_MAIL_SECURE'), false);
    const user = cfg.get<string>('STAGE_MAIL_USER');
    const pass = cfg.get<string>('STAGE_MAIL_PASS');

    if (!user || !pass) {
      log.warn('Mailtrap 사용자/비밀번호가 비어 있습니다. Mailtrap 대시보드에서 값을 확인하세요.');
    }

    log.log(`mail: provider=mailtrap (${host}:${port})`);
    return {
      transport: {
        host, port, secure,
        ...(user && pass ? { auth: { user, pass } } : {}),
        tls: { rejectUnauthorized: false },
      },
      defaults: { from: MAIL_FROM },
    };
  }

  // provider === 'smtp' (prod)
  {
    // 운영 — 일반 SMTP(Gmail/SES/Mailgun 등)
    const host =
      cfg.get<string>('PROD_MAIL_HOST') || 'smtp.gmail.com';
    const port =
      Number(cfg.get<number>('PROD_MAIL_PORT') ?? 587);
    const secure = toBool(cfg.get('PROD_MAIL_SECURE'), false);
    const user = cfg.get<string>('PROD_MAIL_USER');
    const pass = cfg.get<string>('PROD_MAIL_PASS');

    if (!host || !port) {
      throw new Error('SMTP(PROD) 설정 누락: PROD_MAIL_HOST/PROD_MAIL_PORT를 확인하세요.');
    }
    if ((user && !pass) || (!user && pass)) {
      log.warn('PROD_MAIL_USER 또는 PROD_MAIL_PASS 중 하나만 설정됨. auth를 사용하지 않습니다.');
    }

    log.log(`mail: provider=smtp (${host}:${port}) secure=${secure}`);
    return {
      transport: {
        host, port, secure,
        ...(user && pass ? { auth: { user, pass } } : {}),
        tls: { rejectUnauthorized: false },
      },
      defaults: { from: MAIL_FROM },
    };
  }
}
