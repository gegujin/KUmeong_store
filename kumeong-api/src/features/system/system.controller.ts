import { Controller, Get, Query } from '@nestjs/common';
import { MailTestService } from './system.mail-test';

@Controller('system')
export class SystemController {
  constructor(private readonly mailTest: MailTestService) {}

  @Get('mail-test')
  async testMail(@Query('to') to?: string) {
    return this.mailTest.sendSanity(to);
  }
}
