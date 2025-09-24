import { Injectable } from '@nestjs/common';
import { createHash } from 'crypto';

type Expiring = { value: string; expireAt: number };

@Injectable()
export class CodeStoreService {
  private codeMap = new Map<string, Expiring>();     // email → codeHash (TTL)
  private cooldownMap = new Map<string, Expiring>(); // email → flag (TTL)

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

  private del(map: Map<string, Expiring>, key: string) {
    map.delete(key);
  }

  async set(email: string, code: string, ttlSec: number) {
    const hash = createHash('sha256').update(code).digest('hex');
    this.setWithTtl(this.codeMap, this.key(email), hash, ttlSec);
  }

  async verify(email: string, code: string) {
    const saved = this.getIfAlive(this.codeMap, this.key(email));
    if (!saved) return false;
    const hash = createHash('sha256').update(code).digest('hex');
    const ok = hash === saved;
    if (ok) this.del(this.codeMap, this.key(email)); // 일회성
    return ok;
  }

  // ⬇️ 이름을 acquireCooldown 으로 변경 (중복 회피)
  async acquireCooldown(email: string, cooldownSec: number) {
    const k = this.key(email);
    if (this.getIfAlive(this.cooldownMap, k)) return false; // 아직 쿨다운 중
    this.setWithTtl(this.cooldownMap, k, '1', cooldownSec);
    return true;
  }
}
