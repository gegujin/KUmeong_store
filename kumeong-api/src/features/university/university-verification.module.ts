// src/features/university/university-verification.module.ts
import { Module } from '@nestjs/common';
import { UniversityVerificationController } from './university-verification.controller'; // ✅ 중괄호 사용
import { EmailService } from '../../core/email/email.service';
import { CodeStoreService } from '../../core/verify/code-store.service';
import { UniversityDomainService } from '../../core/verify/university-domain.service';

@Module({
  controllers: [UniversityVerificationController],
  providers: [EmailService, CodeStoreService, UniversityDomainService],
})
export class UniversityVerificationModule {}
