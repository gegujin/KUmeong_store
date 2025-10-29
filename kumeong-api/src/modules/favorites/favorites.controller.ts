// src/modules/favorites/favorites.controller.ts
import {
  Controller,
  Post,
  Param,
  UseGuards,
  Get,
  Query,
  Req,
  ParseIntPipe,
  DefaultValuePipe,
  UnauthorizedException,
} from '@nestjs/common';
import { FavoritesService } from './favorites.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
// 전역 prefix 'api' + 버저닝 → /api/v1/favorites
@Controller({ path: 'favorites', version: '1' })
export class FavoritesController {
  constructor(private readonly service: FavoritesService) {}

  @Post(':productId/toggle')
  async toggle(@Req() req: any, @Param('productId') productId: string) {
    const meId: string | undefined = req.user?.id;
    if (!meId) throw new UnauthorizedException('No user id in request');

    // FavoritesService.toggle 은 { isFavorited, favoriteCount } 를 반환해야 함
    const { isFavorited, favoriteCount } = await this.service.toggle(meId, productId);
    return { ok: true, data: { isFavorited, favoriteCount } };
  }

  @Get()
  async listMine(
    @Req() req: any,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    const meId: string | undefined = req.user?.id;
    if (!meId) throw new UnauthorizedException('No user id in request');

    const p = Math.max(1, page || 1);
    const l = Math.min(100, Math.max(1, limit || 20));

    const data = await this.service.listMine(meId, p, l);
    return { ok: true, data }; // { ok:true, data:{ items, total, page, limit } }
  }
}
