import { Module } from '@nestjs/common';
import { MailTestService } from './system.mail-test';
import { SystemController } from './system.controller';

@Module({
  providers: [MailTestService],
  controllers: [SystemController],
})
export class SystemModule {}
