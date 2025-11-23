import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './entities/user.entity';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { UserRepository } from './repositories/user.repository'; // ✅ 추가

@Module({
  imports: [
    // ✅ TypeORM 레포지토리 주입을 위해 반드시 필요
    TypeOrmModule.forFeature([User]),
  ],
  controllers: [UsersController],
  providers: [
    UsersService,
    UserRepository,        // ✅ 추가 (여기가 없으면 Nest가 DataSource를 못 씀)
  ],
  exports: [
    UsersService,
    UserRepository,        // ✅ 다른 모듈에서 사용할 수 있게 export
  ],
})
export class UsersModule {}