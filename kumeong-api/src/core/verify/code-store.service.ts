// src/core/verify/code-store.service.ts
import { Injectable } from '@nestjs/common';
import { createHash } from 'crypto';
import { Redis } from 'ioredis'; // 이미 프로젝트에 구성되어 있다고 가정
@Injectable()
export class CodeStoreService {
  constructor(private readonly redis: Redis) {}
  private key(email: string) { return `verify:univ:${email.toLowerCase()}`; }

  async set(email: string, code: string, ttlSec: number) {
    const hash = createHash('sha256').update(code).digest('hex');
    await this.redis.set(this.key(email), hash, 'EX', ttlSec);
  }
  async verify(email: string, code: string) {
    const k = this.key(email);
    const saved = await this.redis.get(k);
    if (!saved) return false;
    const hash = createHash('sha256').update(code).digest('hex');
    if (hash !== saved) return false;
    await this.redis.del(k); // 일회성
    return true;
  }
  async cooldown(email: string, cooldownSec: number) {
    const ck = `${this.key(email)}:cooldown`;
    const ok = await this.redis.set(ck, '1', 'NX', 'EX', cooldownSec);
    return ok === 'OK';
  }
}
