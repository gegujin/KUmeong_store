// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\users\users.controller.ts
import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { UsersService } from './users.service';

@ApiTags('users')
// ✅ 경로는 'users'만, 버전은 데코레이터로 지정 → /api/v1/users/...
@Controller({ path: 'users', version: '1' })
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @ApiOperation({ summary: '디버그 - DB 연결 상태' })
  @Get('debug/db-info') // GET /api/v1/users/debug/db-info
  dbInfo() {
    return this.usersService.debugDbInfo();
  }

  @ApiOperation({ summary: '디버그 - 유저 이메일 목록' })
  @Get('debug/list-emails') // GET /api/v1/users/debug/list-emails
  listEmails() {
    return this.usersService.debugListEmails();
  }

  @ApiOperation({ summary: '이메일 또는 이름으로 사용자 조회' })
  @ApiQuery({ name: 'query', required: true, description: '이메일(@kku.ac.kr) 또는 이름(완전일치, 대소문자 무시)' })
  @Get('lookup') // GET /api/v1/users/lookup?query=...
  async lookup(@Query('query') query: string) {
    const user = await this.usersService.lookupByQuery(query);
    return { ok: true, user };
  }
}
