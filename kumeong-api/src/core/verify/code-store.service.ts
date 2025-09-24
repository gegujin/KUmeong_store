// src/core/verify/code-store.service.ts
import { Injectable } from '@nestjs/common';
import { createHash } from 'crypto';

type Expiring = { value: string; expireAt: number };

@Injectable()
export class CodeStoreService {
  private code = new Map<string, Expiring>();     // email → codeHash (TTL)
  private cooldown = new Map<string, Expiring>(); // email → flag (TTL)

  private now() { return Date.now(); }
  private key(email: string) { return email.trim().toLowerCase(); }

  private setWithTtl(map: Map<string, Expiring>, key: string, value: string, ttlSec: number) {
    map.set(key, { value, expireAt: this.now() + ttlSec * 1000 });
  }
  private getIfAlive(map: Map<string, Expiring>, key: string): string | null {
    const rec = map.get(key);
    if (!rec) return null;
    if (rec.expireAt < this.now()) { map.delete(key); return null; }
    return rec.value;
  }
  private del(map: Map<string, Expiring>, key: string) { map.delete(key); }

  async set(email: string, code: string, ttlSec: number) {
    const hash = createHash('sha256').update(code).digest('hex');
    this.setWithTtl(this.code, this.key(email), hash, ttlSec);
  }

  async verify(email: string, code: string) {
    const saved = this.getIfAlive(this.code, this.key(email));
    if (!saved) return false;
    const hash = createHash('sha256').update(code).digest('hex');
    const ok = hash === saved;
    if (ok) this.del(this.code, this.key(email)); // 일회성
    return ok;
  }

  async cooldown(email: string, cooldownSec: number) {
    const k = this.key(email);
    if (this.getIfAlive(this.cooldown, k)) return false; // 아직 쿨다운 중
    this.setWithTtl(this.cooldown, k, '1', cooldownSec);
    return true;
  }
}
