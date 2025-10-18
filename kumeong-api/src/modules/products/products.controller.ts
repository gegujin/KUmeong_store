import { 
  Controller, Get, Post, Patch, Delete, Body, Param, Query, Req, BadRequestException, UseInterceptors, UploadedFiles 
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiTags, ApiOperation, ApiConsumes } from '@nestjs/swagger';
import { ProductsService } from './products.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { QueryProductDto } from './dto/query-product.dto';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { Multer } from 'multer';

// Multer 파일 타입 정의
interface MulterFile {
  fieldname: string;
  originalname: string;
  encoding: string;
  mimetype: string;
  size: number;
  destination?: string;
  filename: string;
  path?: string;
  buffer?: Buffer;
}

@ApiTags('products')
@ApiBearerAuth()
@Controller({ path: 'products', version: '1' })
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  @ApiOperation({ summary: '상품 목록 조회' })
  @Get()
  async findAll(@Query() q: QueryProductDto) {
    return { ok: true, data: await this.productsService.findAll(q) };
  }

  @ApiOperation({ summary: '상품 상세 조회' })
  @Get(':id')
  async findOne(@Param('id') id: string) {
    const item = await this.productsService.findOne(id);
    return { ok: true, data: item };
  }

  @ApiOperation({ summary: '상품 등록' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FilesInterceptor('images', 10)) // 최대 10장 이미지
  @Post()
  async create(
    @Body() dto: CreateProductDto,
    @UploadedFiles() files?: Express.Multer.File[],
    @Req() req?: any,
    @CurrentUser() u?: { id: string | number },
  ) {
    const ownerId = ((u?.id ?? req?.header('X-User-Id') ?? '') as any).toString().toLowerCase();
    const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRe.test(ownerId)) throw new BadRequestException('invalid_owner_id');

    const created = await this.productsService.createWithOwner(dto, ownerId, files);
    return { ok: true, data: created };
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
