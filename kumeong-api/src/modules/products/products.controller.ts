// src/products/products.controller.ts
import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  Req,
  UseGuards,
  BadRequestException,
  UseInterceptors,
  UploadedFiles,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiTags,
  ApiOperation,
  ApiConsumes,
} from '@nestjs/swagger';
import { ProductsService } from './products.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { QueryProductDto } from './dto/query-product.dto';
import { FindProductsDto } from './dto/find-products.dto';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import * as multer from 'multer';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { Request } from 'express';

// ----- helpers: 이미지 절대 URL + 썸네일 -----
function toAbsolute(req: Request, p?: string) {
  if (!p) return p;
  if (p.startsWith('/uploads/')) {
    const base = `${req.protocol}://${req.headers.host}`;
    return `${base}${p}`;
  }
  return p; // 이미 절대 URL이면 그대로
}

function decorateProductForClient(req: Request, prod: any) {
  const images = Array.isArray(prod.images)
    ? prod.images
    : prod.images
    ? [prod.images]
    : [];
  const absImages = images.map((p) => toAbsolute(req, p));
  return {
    ...prod,
    images: absImages,
    thumbnail: absImages[0] ?? null,
    thumbnailUrl: absImages[0] ?? null,
  };
}

// ----- Multer: 메모리 저장 + 이미지 필터 + 사이즈 제한 -----
const upload = {
  storage: multer.memoryStorage(),
  limits: {
    files: 10,
    fileSize: 5 * 1024 * 1024, // 5MB
  },
  fileFilter: (
    _req: any,
    file: Express.Multer.File,
    cb: (err: any, accept: boolean) => void,
  ) => {
    if (!file.mimetype?.startsWith('image/')) {
      return cb(new BadRequestException('only_image_allowed'), false);
    }
    cb(null, true);
  },
};

@ApiTags('products')
@ApiBearerAuth()
@Controller({ path: 'products', version: '1' })
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  @ApiOperation({ summary: '상품 목록 조회' })
  @Get()
  async findAll(@Query() q: QueryProductDto, @Req() req: Request) {
    const page = await this.productsService.findAll(q);
    const items = page.items.map((it) => decorateProductForClient(req, it));
    return { ok: true, data: { ...page, items } };
  }

  @ApiOperation({ summary: '상품 상세 조회' })
  @Get(':id')
  async findOne(@Param('id') id: string, @Req() req: Request) {
    const item = await this.productsService.findOne(id);
    return { ok: true, data: decorateProductForClient(req, item) };
  }

  @ApiOperation({ summary: '상품 등록' })
  @ApiConsumes('multipart/form-data')
  @UseGuards(JwtAuthGuard) // ✅ 인증 필수
  @UseInterceptors(FilesInterceptor('images', 10, upload))
  @Post()
  async create(
    @Body() dto: CreateProductDto,
    @UploadedFiles() files: Express.Multer.File[] | undefined,
    @Req() req: Request,
    @CurrentUser() user?: { id: string },
  ) {
    const sellerId =
      user?.id ?? (req as any)?.user?.id ?? req.header('X-User-Id') ?? '';
    const uuidRe =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRe.test(String(sellerId))) {
      throw new BadRequestException('invalid_owner_id');
    }

    const created = await this.productsService.createWithOwner(
      dto,
      String(sellerId).toLowerCase(),
      files,
    );
    return { ok: true, data: decorateProductForClient(req, created) };
  }

  @ApiOperation({ summary: '상품 수정' })
  @Patch(':id')
  async update(@Param('id') id: string, @Body() dto: UpdateProductDto) {
    return { ok: true, data: await this.productsService.update(id, dto) };
  }

  @ApiOperation({ summary: '상품 삭제' })
  @Delete(':id')
  async remove(@Param('id') id: string) {
    return { ok: true, data: await this.productsService.remove(id) };
  }
  
}

