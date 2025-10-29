import { Controller, Post, Delete, Param, Req, UseGuards, UnauthorizedException } from '@nestjs/common';
import { FavoritesService } from './favorites.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

// 전역 prefix 'api' + 버전 v1 → /api/v1/products/:productId/favorite
@UseGuards(JwtAuthGuard)
@Controller({ path: 'products', version: '1' })
export class ProductsFavoriteCompatController {
  constructor(private readonly service: FavoritesService) {}

  @Post(':productId/favorite')
  async add(@Req() req: any, @Param('productId') productId: string) {
    const meId: string | undefined = req.user?.id;
    if (!meId) throw new UnauthorizedException('No user id in request');
    const { isFavorited, favoriteCount } = await this.service.toggle(meId, productId);
    return { ok: true, data: { isFavorited, favoriteCount } };
  }

  @Delete(':productId/favorite')
  async remove(@Req() req: any, @Param('productId') productId: string) {
    const meId: string | undefined = req.user?.id;
    if (!meId) throw new UnauthorizedException('No user id in request');
    const { isFavorited, favoriteCount } = await this.service.toggle(meId, productId);
    return { ok: true, data: { isFavorited, favoriteCount } };
  }
}
