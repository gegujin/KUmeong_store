// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\users\users.controller.ts
import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { UsersService } from './users.service';

@ApiTags('users')
@Controller('v1/users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @ApiOperation({ summary: '디버그 - DB 연결 상태' })
  @Get('debug/db-info')
  dbInfo() {
    return this.usersService.debugDbInfo();
  }

  @ApiOperation({ summary: '디버그 - 유저 이메일 목록' })
  @Get('debug/list-emails')
  listEmails() {
    return this.usersService.debugListEmails();
  }

  @ApiOperation({ summary: '이메일 또는 이름으로 사용자 조회' })
  @Get('lookup')
  async lookup(@Query('query') query: string) {
    const user = await this.usersService.lookupByQuery(query);
    return { ok: true, user };
  }
}
