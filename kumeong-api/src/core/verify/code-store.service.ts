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
  // 이메일 인증코드 저장소 (email -> CodeRecord)
  private readonly codes = new Map<string, CodeRecord>();

  // 일반 TTL 키 저장소 (쿨다운 등) : key -> { value, expiresAt }
  private readonly kv = new Map<string, { value: string; expiresAt: number }>();

  // 정책값 (기본은 EMAIL_*, UNIV_*가 있으면 서비스 레벨에서 병합 사용)
  private readonly ttlSec: number;
  private readonly cooldownSec: number;
  private readonly maxAttempts: number;

  constructor(private readonly cfg: ConfigService) {
    this.ttlSec = Number(this.cfg.get('EMAIL_CODE_TTL_SEC') ?? 300);     // 5분
    this.cooldownSec = Number(this.cfg.get('EMAIL_COOLDOWN_SEC') ?? 60); // 60초
    this.maxAttempts = Number(this.cfg.get('EMAIL_MAX_ATTEMPTS') ?? 5);  // 5회
  }

  /** 내부 키 정규화 (소문자/트림) */
  private norm(emailOrKey: string): string {
    return String(emailOrKey || '').trim().toLowerCase();
  }

  /** 현재 epoch ms */
  private now() {
    return Date.now();
  }

  /** 기본 정책(레거시 호환; 실제 정책 병합은 UniversityVerificationService에서 수행) */
  getPolicy(): Policy {
    return {
      ttlSec: this.ttlSec,
      cooldownSec: this.cooldownSec,
      maxAttempts: this.maxAttempts,
    };
  }

  /** 지금 보내도 되는지 체크 (레거시 사용처 호환용) */
  canSend(email: string): { ok: true; nextSendAt: null } | { ok: false; nextSendAt: string } {
    const key = this.norm(email);
    const rec = this.codes.get(key);
    if (!rec) return { ok: true, nextSendAt: null };

    const next = rec.lastSentAt + this.cooldownSec * 1000;
    if (this.now() >= next) return { ok: true, nextSendAt: null };
    return { ok: false, nextSendAt: new Date(next).toISOString() };
  }

  /**
   * 통합 set:
   * - 이메일 주소 형태면 "인증코드"로 저장 (attempts 초기화, lastSentAt 갱신, ttl 적용)
   * - 그 외 문자열 키면 일반 TTL 키로 저장(쿨다운 등)
   *
   * 컨트롤러에서 다음 두 용도로 사용:
   *   await set(email, code, ttlSec)              // 인증코드
   *   await set(`univ:cooldown:${email}`, '1', s) // 쿨다운
   */
  async set(keyOrEmail: string, value: string, ttlSec: number): Promise<void> {
    const key = this.norm(keyOrEmail);
    const ttlMs = Math.max(0, Number(ttlSec) | 0) * 1000;
    const exp = this.now() + ttlMs;

    if (key.includes('@')) {
      // 이메일 인증코드 레코드
      this.codes.set(key, {
        code: String(value).trim(),
        expiresAt: exp,
        attempts: 0,
        lastSentAt: this.now(),
      });
    } else {
      // 일반 TTL 키(쿨다운 등)
      this.kv.set(key, { value: String(value), expiresAt: exp });
    }
  }

  /**
   * TTL 조회(초)
   * - 일반 TTL 키(쿨다운): kv에서 계산
   * - 이메일 주소가 들어오면 인증코드 TTL 반환
   */
  async ttl(keyOrEmail: string): Promise<number> {
    const key = this.norm(keyOrEmail);
    const now = this.now();

    if (key.includes('@')) {
      const rec = this.codes.get(key);
      if (!rec) return -2; // Redis 호환: 키 없음
      const remain = Math.ceil((rec.expiresAt - now) / 1000);
      return remain > 0 ? remain : -2;
    }

    const item = this.kv.get(key);
    if (!item) return -2;
    const remain = Math.ceil((item.expiresAt - now) / 1000);
    return remain > 0 ? remain : -2;
  }

  /** DEV 전용: 아직 유효한 코드만 조회(만료/시도초과면 null) */
  peekActiveCode(email: string): { code: string; expiresAt: string } | null {
    const key = this.norm(email);
    const rec = this.codes.get(key);
    if (!rec) return null;
    const now = this.now();
    if (now > rec.expiresAt) return null;
    if (rec.attempts >= this.maxAttempts) return null;
    return { code: rec.code, expiresAt: new Date(rec.expiresAt).toISOString() };
  }

  /**
   * 코드 검증
   * - not_found | expired | too_many | mismatch 사유 분리
   * - 실패 시 attempts+1, 한도 도달 시 too_many 반환(레코드 제거)
   * - 성공 시 레코드 제거(1회용)
   */
  verify(email: string, code: string): VerifyResult {
    const key = this.norm(email);
    const rec = this.codes.get(key);
    if (!rec) return { ok: false, reason: 'not_found' };

    const now = this.now();
    if (now > rec.expiresAt) {
      this.codes.delete(key);
      return { ok: false, reason: 'expired' };
    }

    if (rec.attempts >= this.maxAttempts) {
      this.codes.delete(key);
      return { ok: false, reason: 'too_many' };
    }

    const input = String(code).trim();
    if (rec.code !== input) {
      rec.attempts += 1;
      if (rec.attempts >= this.maxAttempts) {
        this.codes.delete(key);
        return { ok: false, reason: 'too_many' };
      }
      this.codes.set(key, rec);
      return { ok: false, reason: 'mismatch' };
    }

    // 성공(1회용)
    this.codes.delete(key);
    return { ok: true };
  }

  /** 수동 초기화(테스트 편의) */
  reset(email: string): void {
    this.codes.delete(this.norm(email));
  }

  // ────────────────────────────────────────────────────────────────
  // (참고) Redis로 확장하고 싶다면:
  // 1) redis 패키지 설치 후 createClient로 this.redis 초기화
  // 2) codeKey/attemptKey/cooldownKey 네임스페이스 정의
  // 3) set/ttl/verify/peekActiveCode를 Redis 분기로 구현
  //    - 인증코드: SETEX code:<email> <ttl> <code>
  //    - 시도수: INCR attempts:<email>, EXPIRE attempts:<email> <ttl>
  //    - 검증 성공 시 DEL code:<email>, attempts:<email>
  //    - 쿨다운: SETEX <cooldownKey> <ttl> "1"
  // 현재는 메모리 구현으로 오류 없이 동작하도록 구성함.
  // ────────────────────────────────────────────────────────────────
}
