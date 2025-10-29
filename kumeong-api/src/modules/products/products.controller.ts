// src/modules/products/products.controller.ts
import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UnauthorizedException,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FilesInterceptor } from '@nestjs/platform-express';
import type { Express } from 'express'; // ✅ 타입만 import해서 TS2694 방지

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

  /** 상품 생성 (이미지 포함) */
  @ApiOperation({ summary: '상품 등록' })
  @ApiConsumes('multipart/form-data') // ✅ Swagger에 파일 업로드 명시
  @UseGuards(JwtAuthGuard)
  @Post()
  @UseInterceptors(FilesInterceptor('images', 10))
  async create(
    @CurrentUser() me: { id: string },
    @Body() dto: CreateProductDto,
    @UploadedFiles() files: Express.Multer.File[] = [], // ✅ 정식 타입
  ): Promise<{ ok: true; data: Product }> {
    if (!me?.id) throw new UnauthorizedException('No authenticated user in request');
    // 서비스가 파일을 받아 productImages에 '/uploads/<filename>'로 저장하도록 구현되어 있어야 함
    const created = await this.productsService.create(me.id, dto, files);
    return { ok: true, data: created };
  }

  /** 상품 수정 (PUT - 전부/대부분 교체, 이미지 포함 가능) */
  @ApiOperation({ summary: '상품 수정(전부/대부분 교체, PUT)' })
  @ApiConsumes('multipart/form-data')
  @UseGuards(JwtAuthGuard)
  @Put(':id')
  @UseInterceptors(FilesInterceptor('images', 10))
  async putUpdate(
    @Param('id') id: string,
    @Body() dto: UpdateProductDto,
    @UploadedFiles() _images: Express.Multer.File[] = [], // 필요 시 서비스에 전달하도록 확장 가능
  ): Promise<{ ok: true; data: Product }> {
    const updated = await this.productsService.update(id, dto /* , _images */);
    return { ok: true, data: updated };
  }

  /** 상품 수정 (PATCH - 부분 수정, 이미지 포함 가능) */
  @ApiOperation({ summary: '상품 수정(부분 수정, PATCH)' })
  @ApiConsumes('multipart/form-data')
  @UseGuards(JwtAuthGuard)
  @Patch(':id')
  @UseInterceptors(FilesInterceptor('images', 10))
  async patchUpdate(
    @Param('id') id: string,
    @Body() dto: UpdateProductDto,
    @UploadedFiles() _images: Express.Multer.File[] = [], // 필요 시 서비스에 전달하도록 확장 가능
  ): Promise<{ ok: true; data: Product }> {
    const updated = await this.productsService.update(id, dto /* , _images */);
    return { ok: true, data: updated };
  }

  /** 상품 삭제 (소프트 삭제) */
  @ApiOperation({ summary: '상품 삭제' })
  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  async remove(
    @Param('id') id: string,
  ): Promise<{ ok: true; data: { deleted: true; id: string } }> {
    const result = await this.productsService.remove(id);
    return { ok: true, data: result };
  }
  
}
