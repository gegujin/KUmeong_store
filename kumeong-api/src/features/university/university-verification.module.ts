import { Module } from '@nestjs/common';
import { UniversityVerificationController } from './university-verification.controller';
// 다음 단계에서 실제 서비스들 주입 예정
// import { EmailService } from '../../core/email/email.service';
// import { CodeStoreService } from '../../core/verify/code-store.service';
// import { UniversityDomainService } from '../../core/verify/university-domain.service';

@Module({
  controllers: [UniversityVerificationController],
  providers: [
    // EmailService,
    // CodeStoreService,
    // UniversityDomainService,
  ],
})
export class UniversityVerificationModule {}
