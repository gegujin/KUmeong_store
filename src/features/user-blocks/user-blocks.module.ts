// src/features/user-blocks/user-blocks.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserBlock } from './entities/user-block.entity';
import { UserBlocksService } from './user-blocks.service';

@Module({
  imports: [TypeOrmModule.forFeature([UserBlock])],
  providers: [UserBlocksService],
  exports: [UserBlocksService],
})
export class UserBlocksModule {}
