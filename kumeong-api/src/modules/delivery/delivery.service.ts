import { Injectable, BadRequestException, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DeliveryMembership } from './entities/delivery-membership.entity';
import { SignupDto } from './dto/signup.dto';
import { User } from '../users/entities/user.entity';
// (선택) 엔티티가 @PrimaryGeneratedColumn('uuid')가 아니라면 필요
import { randomUUID } from 'crypto';

@Injectable()
export class DeliveryService {
  constructor(
    @InjectRepository(DeliveryMembership)
    private readonly memberships: Repository<DeliveryMembership>,
    @InjectRepository(User)
    private readonly users: Repository<User>,
  ) {}

  async getMembership(userId: string) {
    const m = await this.memberships.findOne({ where: { userId } });
    return { isMember: !!m, transport: m?.transport ?? null };
  }

  async signup(userId: string, dto: SignupDto) {
    // 1) 사용자 존재 확인
    const exists = await this.users.exist({ where: { id: userId } });
    if (!exists) throw new BadRequestException('user not found');

    // 2) 이메일/도메인 검증
    const email = (dto.email ?? '').trim().toLowerCase();
    if (!email.includes('@')) throw new BadRequestException('invalid email');
    const domain = email.split('@')[1];
    if (domain !== 'kku.ac.kr') {
      throw new BadRequestException('kku email required');
    }

    // 3) 이미 멤버인지 확인
    const already = await this.memberships.findOne({ where: { userId } });
    if (already) {
      throw new ConflictException('already a member');
    }

    // 4) 신규 멤버십 생성 (❗ email/universityToken 포함)
    const membership = this.memberships.create({
      // id: randomUUID(), // ← 엔티티가 @PrimaryGeneratedColumn('uuid')이면 주석 유지
      userId,
      email,                               // ✅ 반드시 넣기
      transport: dto.transport,            // '도보' | '자전거' | '오토바이' | '기타'
      universityToken: dto.univToken ?? null, // ❑ 컬럼명 매핑 주의
    });

    await this.memberships.save(membership);

    return { isMember: true, transport: membership.transport };
  }
}
