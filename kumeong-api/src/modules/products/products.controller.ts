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
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import * as multer from 'multer';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

// Multer 옵션: 메모리 저장 + 파일/사이즈 필터
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
    // 이미지 계열만 허용
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
@UseGuards(JwtAuthGuard) // ✅ JWT 인증 필수
@UseInterceptors(FilesInterceptor('images', 10, upload))
@Post()
async create(
  @Body() dto: CreateProductDto,
  @UploadedFiles() files: Express.Multer.File[],
  @Req() req: any,
  @CurrentUser() user?: { id: string },
) {
  const sellerId = user?.id ?? req?.user?.id;
  if (!sellerId) {
    throw new BadRequestException('로그인된 사용자 정보가 없습니다.');
  }

  const uuidRe =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuidRe.test(sellerId)) {
    throw new BadRequestException('Invalid seller UUID');
  }

  const created = await this.productsService.createWithOwner(dto, sellerId, files);
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
