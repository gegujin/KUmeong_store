import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './entities/user.entity';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}

// src/app.module.ts (또는 src/database/typeorm.config.ts)
TypeOrmModule.forRoot({
  type: 'mysql',
  host: 'localhost',
  port: 3306,
  username: 'root',
  password: '...',
  database: 'kumeong_store',

  // ✅ 지금은 실제 물리 테이블(소문자)에 "맞춰서" 붙는 게 목적
  synchronize: true,                 // 개발 중만 켜두기
  // namingStrategy: new SnakeNamingStrategy(),  // ❌ 임시로 주석. 자동 이름 변환이 테이블명/컬럼명 충돌 유발

  autoLoadEntities: true,
  logging: ['error', 'warn'],        // 필요 시 'schema' 추가해서 DDL 로그 확인 가능
});
