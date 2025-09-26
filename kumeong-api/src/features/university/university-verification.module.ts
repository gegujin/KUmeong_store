// kumeong-api/src/features/university/university-verification.module.ts
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt'; // ✅ 추가
import { UniversityVerificationController } from './university-verification.controller';
import { UniversityVerificationService } from './university-verification.service';
import { CodeStoreService } from '../../core/verify/code-store.service';
import { UniversityDomainService } from '../../core/verify/university-domain.service';
import { UniversityEmailService } from './university-email.service';
import { UsersModule } from '../../modules/users/users.module'; // ✅ UsersService 주입용

@Module({
  imports: [
    UsersModule,
    JwtModule.register({}), // ✅ JwtService 프로바이더만 주입(기본 설정 불필요)
  ],
  controllers: [UniversityVerificationController],
  providers: [
    UniversityVerificationService,
    CodeStoreService,
    UniversityDomainService,
    UniversityEmailService,
  ],
})
export class UniversityVerificationModule {}
