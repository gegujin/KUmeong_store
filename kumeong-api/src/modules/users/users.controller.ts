// // C:\Users\82105\KU-meong Store\kumeong-api\src\modules\users\users.service.ts
// import { Injectable, NotFoundException } from '@nestjs/common';
// import { InjectRepository } from '@nestjs/typeorm';
// import { DataSource, Repository } from 'typeorm';
// import { User } from './entities/user.entity';

// type RawUserRow = { id: number; name: string | null; email: string | null };

// @Injectable()
// export class UsersService {
//   constructor(
//     private readonly ds: DataSource,
//     @InjectRepository(User)
//     private readonly usersRepo: Repository<User>,
//   ) {}

//   // =========================================================
//   // 개발/디버그용: DB 연결 정보/상태
//   // =========================================================
//   async debugDbInfo() {
//     try {
//       const opt: any = this.ds.options || {};
//       const ping = await this.ds.query('SELECT 1 AS ok');
//       return {
//         type: opt.type ?? null,
//         host: opt.host ?? null,
//         port: opt.port ?? null,
//         database: opt.database ?? null,
//         pingOk: Array.isArray(ping) && ping.length > 0 ? ping[0].ok === 1 : false,
//       };
//     } catch (e: any) {
//       return { error: e?.message ?? String(e) };
//     }
//   }

//   // =========================================================
//   // 개발/디버그용: 이메일/유저 샘플 목록
//   // =========================================================
//   async debugListEmails() {
//     try {
//       const total = await this.usersRepo.count();
//       const rows = await this.usersRepo
//         .createQueryBuilder('u')
//         .select(['u.id AS id', 'u.name AS name', 'u.email AS email'])
//         .where('u.deletedAt IS NULL')
//         .orderBy('u.createdAt', 'DESC')
//         .take(50)
//         .getRawMany<RawUserRow>();

//       return {
//         total,
//         rows: rows.map(r => ({ id: String(r.id), name: r.name, email: r.email })),
//       };
//     } catch (e: any) {
//       return { error: e?.message ?? String(e) };
//     }
//   }

//   // =========================================================
//   // 이메일(@kku.ac.kr) 또는 이름(완전일치, 소문자)로 사용자 1명 조회
//   // =========================================================
//   async lookupByQuery(
//     rawInput: string,
//   ): Promise<{ id: string; name?: string; email?: string }> {
//     const raw = (rawInput ?? '').trim().toLowerCase();
//     if (!raw) throw new NotFoundException('USER_NOT_FOUND');

//     const looksEmail = /^[^@\s]+@kku\.ac\.kr$/.test(raw);

//     if (looksEmail) {
//       const byEmail = await this.usersRepo
//         .createQueryBuilder('u')
//         .select(['u.id AS id', 'u.name AS name', 'u.email AS email'])
//         .where('LOWER(u.email) = :raw', { raw })
//         .andWhere('u.deletedAt IS NULL')
//         .getRawOne<RawUserRow>();

//       if (byEmail) {
//         return { id: String(byEmail.id), name: byEmail.name ?? undefined, email: byEmail.email ?? undefined };
//       }
//       throw new NotFoundException('USER_NOT_FOUND');
//     }

//     // 이름 완전일치(소문자) 조회
//     const byName = await this.usersRepo
//       .createQueryBuilder('u')
//       .select(['u.id AS id', 'u.name AS name', 'u.email AS email'])
//       .where('LOWER(u.name) = :raw', { raw })
//       .andWhere('u.deletedAt IS NULL')
//       .orderBy('u.id', 'ASC')
//       .take(1)
//       .getRawOne<RawUserRow>();

//     if (byName) {
//       return { id: String(byName.id), name: byName.name ?? undefined, email: byName.email ?? undefined };
//     }

//     throw new NotFoundException('USER_NOT_FOUND');
//   }
// }


// src/modules/users/users.controller.ts
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
