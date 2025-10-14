// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\products\products.controller.ts
import {
  Body,
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Query,
  Req,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
<<<<<<< HEAD
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Request } from 'express';
=======
import {
  ApiBearerAuth,
  ApiForbiddenResponse,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiCreatedResponse,
  ApiUnauthorizedResponse,
  ApiTags,
  ApiConsumes,
} from '@nestjs/swagger';
import { FilesInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
>>>>>>> 3807f98184bcd254c51b5ae0071d8655a85553ff

import { ProductsService } from '../products/products.service';              // ← ../products → ./ 로 수정
import { CreateProductDto } from '../products/dto/create-product.dto';       // ← ../products/dto → ./
import { UpdateProductDto } from '../products/dto/update-product.dto';
import { QueryProductDto } from '../products/dto/query-product.dto';
import { Product } from '../products/entities/product.entity';

import { CurrentUser } from '../auth/decorators/current-user.decorator'; // modules/products → modules/auth 경로 OK
// import { OwnerGuard } ... (필요 시 추가)

@ApiTags('products')
@ApiBearerAuth()
@Controller('v1/products')
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
  @Post()
  async create(
    @Body() dto: CreateProductDto,
<<<<<<< HEAD
    @Req() req: Request,
    @CurrentUser() u?: { id: string | number },
=======
    @CurrentUser() u: SafeUser,
    @UploadedFiles() files: Express.Multer.File[],
>>>>>>> 3807f98184bcd254c51b5ae0071d8655a85553ff
  ) {
    // user.id(숫자여도) → 문자열 UUID로 정규화, 없으면 X-User-Id 헤더 사용
    const ownerId = ((u?.id ?? req.header('X-User-Id') ?? '') as any)
      .toString()
      .toLowerCase();

    // UUID 형식 검증
    const uuidRe =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRe.test(ownerId)) {
      throw new BadRequestException('invalid_owner_id');
    }

    const created = await this.productsService.createWithOwner(dto, ownerId);
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

  /** 상품 삭제 */
  @ApiOperation({ summary: '상품 삭제' })
  @Delete(':id')
  async remove(
    @Param('id') id: string,
  ): Promise<{ ok: true; data: { deleted: true; id: string } }> {
    const result = await this.productsService.remove(id);
    return { ok: true, data: result };
  }
}


// import {
//   Body,
//   Controller,
//   Get,
//   Post,
//   Param,
//   Patch,
//   Delete,
//   UseGuards,
//   ParseUUIDPipe,
//   Query,
//   UploadedFiles,
//   UseInterceptors,
// } from '@nestjs/common';
// import {
//   ApiBearerAuth,
//   ApiForbiddenResponse,
//   ApiNotFoundResponse,
//   ApiOkResponse,
//   ApiCreatedResponse,
//   ApiUnauthorizedResponse,
//   ApiTags,
//   ApiConsumes,
// } from '@nestjs/swagger';
// import { FilesInterceptor } from '@nestjs/platform-express';
// import { diskStorage } from 'multer';
// import { extname } from 'path';
// import type { File as MulterFile } from 'multer';

// import { ProductsService } from './products.service';
// import { CreateProductDto } from './dto/create-product.dto';
// import { UpdateProductDto } from './dto/update-product.dto';
// import { QueryProductDto } from './dto/query-product.dto';
// import {
//   OkItemProductDto,
//   OkPageProductDto,
//   DeleteResultDto,
// } from './dto/product.responses';

// import { JwtAuthGuard } from '../auth/jwt-auth.guard';
// import { OwnerGuard } from './guards/owner.guard';
// import { Public } from '../auth/decorators/public.decorator';
// import { CurrentUser } from '../auth/decorators/current-user.decorator';
// import type { SafeUser } from '../auth/types/user.types';

// @ApiTags('Products')
// @Controller({ path: 'products', version: '1' })
// export class ProductsController {
//   constructor(private readonly productsService: ProductsService) {}

//   // 🔓 공개: 목록
//   @Public()
//   @Get()
//   @ApiOkResponse({ type: OkPageProductDto, description: '상품 목록(페이지네이션)' })
//   async findAll(@Query() query: QueryProductDto) {
//     const { items, page, limit, total, pages } =
//       await this.productsService.findAll(query);
//     return { ok: true, data: { items, page, limit, total, pages } };
//   }

//   // 🔓 공개: 상세
//   @Public()
//   @Get(':id')
//   @ApiOkResponse({ type: OkItemProductDto, description: '상품 상세' })
//   @ApiNotFoundResponse({ description: 'Product not found' })
//   async findOne(@Param('id', new ParseUUIDPipe({ version: '4' })) id: string) {
//     const item = await this.productsService.findOne(id);
//     return { ok: true, data: item };
//   }

//   // 🔐 보호: 생성 (로그인 필요, 이미지 업로드 지원)
//   @ApiBearerAuth()
//   @UseGuards(JwtAuthGuard)
//   @Post()
//   @ApiCreatedResponse({ type: OkItemProductDto, description: '생성 성공' })
//   @ApiUnauthorizedResponse({ description: 'Unauthorized' })
//   @ApiConsumes('multipart/form-data')
//   @UseInterceptors(
//     FilesInterceptor('images', 10, {
//       storage: diskStorage({
//         destination: './uploads/products', // 저장 경로
//         filename: (req, file, cb) => {
//           const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
//           const ext = extname(file.originalname);
//           cb(null, `${file.fieldname}-${uniqueSuffix}${ext}`);
//         },
//       }),
//       fileFilter: (req, file, cb) => {
//         if (!file.mimetype.match(/\/(jpg|jpeg|png|gif)$/)) {
//           return cb(new Error('이미지 파일만 업로드 가능합니다.'), false);
//         }
//         cb(null, true);
//       },
//     }),
//   )
//   async create(
//     @Body() dto: CreateProductDto,
//     @CurrentUser() u: SafeUser,
//     @UploadedFiles() files: MulterFile[],
//   ) {
//     // 업로드된 이미지 URL 배열 생성
//     if (files && files.length > 0) {
//       dto.images = files.map((file) => `/uploads/products/${file.filename}`);
//     }
//     const created = await this.productsService.createWithOwner(dto, u.id);
//     return { ok: true, data: created };
//   }

//   // 🔐 보호: 수정 (소유자만)
//   @ApiBearerAuth()
//   @UseGuards(JwtAuthGuard, OwnerGuard)
//   @Patch(':id')
//   @ApiOkResponse({ type: OkItemProductDto, description: '수정 성공' })
//   @ApiNotFoundResponse({ description: 'Product not found' })
//   @ApiUnauthorizedResponse({ description: 'Unauthorized' })
//   @ApiForbiddenResponse({ description: 'Only owner can modify/delete' })
//   async update(
//     @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
//     @Body() dto: UpdateProductDto,
//   ) {
//     const updated = await this.productsService.update(id, dto);
//     return { ok: true, data: updated };
//   }

//   // 🔐 보호: 삭제 (소유자만)
//   @ApiBearerAuth()
//   @UseGuards(JwtAuthGuard, OwnerGuard)
//   @Delete(':id')
//   @ApiOkResponse({ type: DeleteResultDto, description: '삭제 성공' })
//   @ApiNotFoundResponse({ description: 'Product not found' })
//   @ApiUnauthorizedResponse({ description: 'Unauthorized' })
//   @ApiForbiddenResponse({ description: 'Only owner can modify/delete' })
//   async remove(@Param('id', new ParseUUIDPipe({ version: '4' })) id: string) {
//     const res = await this.productsService.remove(id);
//     return { deleted: true, id: res.id };
//   }
// }
