// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\products\products.controller.ts
import {
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Body,
  Query,
  UseGuards,
  UnauthorizedException, // ✅ 추가
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { ProductsService } from './products.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { QueryProductDto } from './dto/query-product.dto';
import { Product } from './entities/product.entity';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('products')
@ApiBearerAuth()
@Controller({ path: 'products', version: '1' })
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  /** 전체 조회 (검색/필터/정렬/페이지네이션) */
  @ApiOperation({ summary: '상품 목록 조회' })
  @Get()
  async findAll(@Query() q: QueryProductDto) {
    const data = await this.productsService.findAll(q);
    return { ok: true, data };
  }

  /** 단건 조회 */
  @ApiOperation({ summary: '상품 상세 조회' })
  @Get(':id')
  async findOne(@Param('id') id: string): Promise<{ ok: true; data: Product }> {
    const item = await this.productsService.findOne(id);
    if (!item) throw new NotFoundException('Product not found');
    return { ok: true, data: item };
  }

  /** 상품 생성 */
  @ApiOperation({ summary: '상품 등록' })
  @UseGuards(JwtAuthGuard)
  @Post()
  async create(
    @CurrentUser() me: { id: string }, // ✅ 안전하게 id만 사용
    @Body() dto: CreateProductDto,
  ): Promise<{ ok: true; data: Product }> {
    if (!me?.id) throw new UnauthorizedException('No authenticated user in request');
    const created = await this.productsService.create(me.id, dto); // ✅ 서비스는 sellerId: string
    return { ok: true, data: created };
  }

  /** 상품 수정 */
  @ApiOperation({ summary: '상품 수정' })
  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body() dto: UpdateProductDto,
  ): Promise<{ ok: true; data: Product }> {
    const updated = await this.productsService.update(id, dto);
    return { ok: true, data: updated };
  }

  /** 상품 삭제 (소프트 삭제) */
  @ApiOperation({ summary: '상품 삭제' })
  @Delete(':id')
  async remove(
    @Param('id') id: string,
  ): Promise<{ ok: true; data: { deleted: true; id: string } }> {
    const result = await this.productsService.remove(id);
    return { ok: true, data: result };
  }
}
