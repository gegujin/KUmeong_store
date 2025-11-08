// src/modules/users/repositories/user.repository.ts
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity';

@Injectable()
export class UserRepository {
  constructor(
    @InjectRepository(User)
    private readonly repo: Repository<User>,
  ) {}

  // 예시 메서드들
  findByEmail(email: string) {
    return this.repo.findOne({ where: { email } });
  }

  createAndSave(partial: Partial<User>) {
    const ent = this.repo.create(partial);
    return this.repo.save(ent);
  }
}
