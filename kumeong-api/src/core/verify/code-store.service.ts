// kumeong-api/src/core/verify/code-store.service.ts
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type VerifyReason = 'expired' | 'mismatch' | 'too_many' | 'not_found';
export interface VerifyResult { ok: boolean; reason?: VerifyReason; }

export interface Policy {
  ttlSec: number;        // 코드 유효시간(초)
  cooldownSec: number;   // 재발송 쿨다운(초)
  maxAttempts: number;   // 검증 최대 시도횟수(실패 시만 증가)
}

type CodeRecord = {
  code: string;
  expiresAt: number;   // epoch ms
  attempts: number;    // 실패 누적
  lastSentAt: number;  // 마지막 발송 시각 epoch ms
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

  /** 내부 키 정규화 (소문자/트림) */
  private norm(email: string): string {
    return String(email || '').trim().toLowerCase();
  }

  getPolicy(): Policy {
    return {
      ttlSec: this.ttlSec,
      cooldownSec: this.cooldownSec,
      maxAttempts: this.maxAttempts,
    };
  }

  /** 지금 보내도 되는지 체크 (쿨다운) */
  canSend(email: string): { ok: true; nextSendAt: null } | { ok: false; nextSendAt: string } {
    const key = this.norm(email);
    const rec = this.store.get(key);
    if (!rec) return { ok: true, nextSendAt: null };

    const now = Date.now();
    const next = rec.lastSentAt + this.cooldownSec * 1000;
    if (now >= next) return { ok: true, nextSendAt: null };
    return { ok: false, nextSendAt: new Date(next).toISOString() };
  }

  /** 메일 발송 성공 후 코드 저장/갱신 */
  set(email: string, code: string): void {
    const key = this.norm(email);
    const now = Date.now();
    this.store.set(key, {
      code: String(code).trim(),
      expiresAt: now + this.ttlSec * 1000,
      attempts: 0,
      lastSentAt: now,
    });
  }

  /**
   * 코드 검증
   * - not_found | expired | too_many | mismatch 사유 분리
   * - 실패 시 attempts+1, 한도 도달 시 too_many 반환
   * - 성공 시 레코드 제거(1회용)
   */
  verify(email: string, code: string): VerifyResult {
    const key = this.norm(email);
    const rec = this.store.get(key);
    if (!rec) return { ok: false, reason: 'not_found' };

    const now = Date.now();
    if (now > rec.expiresAt) {
      this.store.delete(key);
      return { ok: false, reason: 'expired' };
    }

    if (rec.attempts >= this.maxAttempts) {
      this.store.delete(key);
      return { ok: false, reason: 'too_many' };
    }

    const input = String(code).trim();
    if (rec.code !== input) {
      rec.attempts += 1;
      // 한도 도달 시점에서 즉시 too_many로 전환
      if (rec.attempts >= this.maxAttempts) {
        this.store.delete(key);
        return { ok: false, reason: 'too_many' };
      }
      this.store.set(key, rec);
      return { ok: false, reason: 'mismatch' };
    }

    // 성공(1회용) → 저장소에서 제거
    this.store.delete(key);
    return { ok: true };
  }

  /** 수동 초기화(테스트 편의) */
  reset(email: string): void {
    this.store.delete(this.norm(email));
  }
}
