// kumeong-api/src/core/verify/code-store.service.ts
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

type CodeRecord = {
  code: string;        // 3단계에서 실제 값 사용 예정
  expiresAt: number;   // epoch ms
  attempts: number;    // verify 시도 횟수
  lastSentAt: number;  // 마지막 발송 시각(epoch ms)
};

@Injectable()
export class CodeStoreService {
  private readonly store = new Map<string, CodeRecord>();

  private readonly ttlSec: number;
  private readonly cooldownSec: number;
  private readonly maxAttempts: number;

  constructor(private readonly cfg: ConfigService) {
    this.ttlSec = Number(this.cfg.get('EMAIL_CODE_TTL_SEC') ?? 300);     // 5분
    this.cooldownSec = Number(this.cfg.get('EMAIL_COOLDOWN_SEC') ?? 60); // 60초
    this.maxAttempts = Number(this.cfg.get('EMAIL_MAX_ATTEMPTS') ?? 5);  // 5회
  }

  getPolicy() {
    return { ttlSec: this.ttlSec, cooldownSec: this.cooldownSec, maxAttempts: this.maxAttempts };
  }

  /** 지금 보내도 되는지 체크 */
  canSend(email: string): { ok: true; nextSendAt: null } | { ok: false; nextSendAt: string } {
    const rec = this.store.get(email);
    if (!rec) return { ok: true, nextSendAt: null };

    const now = Date.now();
    const next = rec.lastSentAt + this.cooldownSec * 1000;
    if (now >= next) return { ok: true, nextSendAt: null };
    return { ok: false, nextSendAt: new Date(next).toISOString() };
  }

  /** 3단계에서 사용: 코드 저장/갱신 */
  set(email: string, code: string) {
    const now = Date.now();
    this.store.set(email, {
      code,
      expiresAt: now + this.ttlSec * 1000,
      attempts: 0,
      lastSentAt: now,
    });
  }

  /** 3단계에서 사용: 검증 */
  verify(email: string, code: string):
    | { ok: true }
    | { ok: false; reason: 'not_found' | 'expired' | 'mismatch' | 'too_many' } {
    const rec = this.store.get(email);
    if (!rec) return { ok: false, reason: 'not_found' };
    const now = Date.now();
    if (now > rec.expiresAt) { this.store.delete(email); return { ok: false, reason: 'expired' }; }
    if (rec.attempts >= this.maxAttempts) { this.store.delete(email); return { ok: false, reason: 'too_many' }; }
    if (rec.code !== code) { rec.attempts += 1; this.store.set(email, rec); return { ok: false, reason: 'mismatch' }; }
    this.store.delete(email);
    return { ok: true };
  }

  reset(email: string) { this.store.delete(email); }
}
