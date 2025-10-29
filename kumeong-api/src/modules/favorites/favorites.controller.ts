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
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FavoritesService } from './favorites.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard'; // 경로 프로젝트 구조에 맞춤

@ApiTags('favorites')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
// 전역 prefix + 버저닝 적용 시: /api/v1/...
@Controller({ version: '1' })
export class FavoritesController {
  constructor(private readonly service: FavoritesService) {}

  // --- A) 기존 경로 유지: POST /api/v1/favorites/:productId/toggle
  @Post('favorites/:productId/toggle')
  @ApiOperation({ summary: '상품 찜 토글 (구 경로)' })
  async toggleLegacy(@Req() req: any, @Param('productId') productId: string) {
    const meId: string | undefined = req.user?.id;
    if (!meId) throw new UnauthorizedException('No user id in request');
    const res = await this.service.toggle(meId, productId);
    // 서비스가 { isFavorited, favoriteCount, productId } 반환하도록 이미 수정됨
    return { success: true, data: res };
  }

  // --- B) 권장 경로: POST /api/v1/products/:id/favorite
  @Post('products/:id/favorite')
  @ApiOperation({ summary: '상품 찜 토글 (권장 경로)' })
  async toggle(@Req() req: any, @Param('id') productId: string) {
    const meId: string | undefined = req.user?.id;
    if (!meId) throw new UnauthorizedException('No user id in request');
    const res = await this.service.toggle(meId, productId);
    return { success: true, data: res };
  }

  // GET /api/v1/favorites/me?page=&limit=
  @Get('favorites/me')
  @ApiOperation({ summary: '내가 찜한 상품 목록' })
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
    return { success: true, data }; // { items, total, page, limit }
  }
}
