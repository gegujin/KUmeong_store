import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Favorite } from './entities/favorite.entity';
import { Product } from '../products/entities/product.entity';
import { FavoritesService } from './favorites.service';
import { FavoritesController } from './favorites.controller';
import { ProductsFavoriteCompatController } from './products-favorite-compat.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Favorite, Product])],
  providers: [FavoritesService],
  controllers: [FavoritesController, ProductsFavoriteCompatController],
  exports: [FavoritesService],
})
export class FavoritesModule {}
