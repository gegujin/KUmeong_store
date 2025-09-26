// kumeong-api/src/features/university/university-verification.module.ts
import { Module } from '@nestjs/common';
import { UniversityVerificationController } from './university-verification.controller';
import { CodeStoreService } from '../../core/verify/code-store.service';
import { UniversityDomainService } from '../../core/verify/university-domain.service';
import { UniversityEmailService } from './university-email.service';
import { UsersModule } from '../../modules/users/users.module'; // ✅ UsersService 주입용

@Module({
  imports: [UsersModule], // ✅ 추가
  controllers: [UniversityVerificationController],
  providers: [CodeStoreService, UniversityDomainService, UniversityEmailService],
})
export class UniversityVerificationModule {}
