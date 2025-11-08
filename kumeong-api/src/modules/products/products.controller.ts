// kumeong-api/src/modules/products/products.controller.ts
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
  UnauthorizedException,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
  ApiConsumes,
} from '@nestjs/swagger';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import { productImageStorage } from './upload.util';

import { ProductsService } from './products.service';
import { ConfigService } from '@nestjs/config';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { QueryProductDto } from './dto/query-product.dto';
import { Product } from './entities/product.entity';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

// ----- 파일명 유틸 (클래스 밖에 선언) -----
function sanitizeFilename(name: string) {
  const base = name.replace(/\s+/g, '_').replace(/[^a-zA-Z0-9._-]/g, '');
  const ts = Date.now();
  return `${ts}-${base}`.slice(0, 200);
}

@ApiTags('products')
@ApiBearerAuth()
@Controller({ path: 'products', version: '1' })
export class ProductsController {
  constructor(
    private readonly productsService: ProductsService,
    private readonly cfg: ConfigService,
  ) {}

  /** 상대경로(`/uploads/...`) → 절대 URL로 보정 */
  private absUrl = (u?: string | null) => {
    if (!u) return null;
    if (/^https?:\/\//i.test(u)) return u;
    const port = Number(this.cfg.get<string>('PORT') ?? 3000);
    const base = this.cfg.get<string>('PUBLIC_BASE_URL') || `http://localhost:${port}`;
    return `${base}${u.startsWith('/') ? '' : '/'}${u}`;
  };

  /** 홈/목록 카드용 응답 매핑 */
  private mapHomeCard = (p: any) => {
    const first = p?.images?.[0]?.url as string | undefined;
    return {
      id: p.id,
      title: p.title,
      priceWon: p.priceWon,
      locationText: p.locationText ?? null,
      status: p.status,
      createdAt: p.createdAt,
      thumbnailUrl: this.absUrl(first),
      imageUrls: (p.images || []).map((i: any) => this.absUrl(i.url)),
    };
  };

  /** 전체 조회 (검색/필터/정렬/페이지네이션) */
  @ApiOperation({ summary: '상품 목록 조회' })
  @Get()
  async findAll(@Query() q: QueryProductDto) {
    const data = await this.productsService.findAll(q);
    return {
      ok: true,
      data: {
        ...data,
        items: data.items.map(this.mapHomeCard),
      },
    };
  }

  /** 단건 조회 */
  @ApiOperation({ summary: '상품 상세 조회' })
  @Get(':id')
  async findOne(@Param('id') id: string): Promise<{ ok: true; data: Product }> {
    const item = await this.productsService.findOne(id);
    if (!item) throw new NotFoundException('Product not found');
    const mapped: any = {
      ...item,
      images: (item as any)?.images?.map((i: any) => ({ ...i, url: this.absUrl(i.url) })) ?? [],
    };
    return { ok: true, data: mapped };
  }

  /** 상품 생성 (multipart/form-data + files.images[]) */
  @ApiOperation({ summary: '상품 등록' })
  @ApiConsumes('multipart/form-data')
  @UseGuards(JwtAuthGuard)
  @UseInterceptors(
    FileFieldsInterceptor([{ name: 'images', maxCount: 10 }], {
      storage: productImageStorage,
      fileFilter: (_req, file, cb) => {
        if (/^image\//i.test(file.mimetype)) cb(null, true);
        else cb(null, false);
      },
      limits: { fileSize: 5 * 1024 * 1024, files: 10 }, // 5MB, 최대 10장
    }),
  )
  @Post()
  async create(
    @CurrentUser() me: { id: string },
    @Body() dto: CreateProductDto,
    @UploadedFiles() files?: { images?: Express.Multer.File[] },
  ): Promise<{ ok: true; data: Product }> {
    if (!me?.id) throw new UnauthorizedException('No authenticated user in request');
    const created = await this.productsService.create(me.id, dto, files?.images ?? []);
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
