// src/features/user-blocks/user-blocks.service.ts
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserBlock } from './entities/user-block.entity';

@Injectable()
export class UserBlocksService {
  constructor(
    @InjectRepository(UserBlock)
    private readonly repo: Repository<UserBlock>,
  ) {}

  /** 차단 생성 (AUTO_INCREMENT/DEFAULT는 DB가 처리) */
  async block(blockerId: string, blockedId: string) {
    const row = this.repo.create({ blockerId, blockedId });
    return await this.repo.save(row); // uq_user_block 위반 시 DB 에러 발생
  }

  /** 차단 해제 */
  async unblock(blockerId: string, blockedId: string) {
    await this.repo.delete({ blockerId, blockedId });
    return { ok: true };
  }
}
