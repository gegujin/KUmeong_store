import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DeliveryController } from './delivery.controller';
import { DeliveryService } from './delivery.service';
import { DeliveryMembership } from './entities/delivery-membership.entity';
import { User } from '../users/entities/user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([DeliveryMembership, User])],
  controllers: [DeliveryController],
  providers: [DeliveryService],
  exports: [],
})
export class DeliveryModule {}
