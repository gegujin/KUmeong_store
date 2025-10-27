// src/features/favorites/favorites.controller.ts
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
// 전역 prefix가 'api', URI 버전닝을 쓰고 있다면 아래 설정으로 /api/v1/favorites 가 됩니다.
@Controller({ path: 'favorites', version: '1' })
export class FavoritesController {
  constructor(private readonly service: FavoritesService) {}

  @Post(':productId/toggle')
  async toggle(@Req() req: any, @Param('productId') productId: string) {
    const meId: string | undefined = req.user?.id;
    if (!meId) throw new UnauthorizedException('No user id in request');
    const res = await this.service.toggle(meId, productId);
    return { ok: true, ...res }; // { ok:true, isFavorited: true/false }
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
