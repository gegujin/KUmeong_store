// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\products\dto\product.responses.ts
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ProductStatus } from '../entities/product.entity';

export class ProductDto {
  @ApiProperty({ example: 'uuid' }) id!: string;
  @ApiProperty({ example: '캠퍼스 패딩' }) title!: string;
  @ApiProperty({ example: 30000 }) price!: number;
  @ApiProperty({ enum: ProductStatus, example: ProductStatus.ON_SALE }) status!: ProductStatus; // ✅ LISTED → ON_SALE

  @ApiPropertyOptional({ example: '거의 새상품입니다.', nullable: true })
  description?: string | null;

  @ApiPropertyOptional({ example: '의류', nullable: true })
  category?: string | null;

  @ApiPropertyOptional({ type: [String], example: ['https://.../img1.jpg'], nullable: true })
  images?: string[] | null;

  @ApiProperty({ example: 'owner-uuid' }) ownerId!: string;
  @ApiProperty({ example: '2025-09-13T12:34:56.789Z' }) createdAt!: Date;
  @ApiProperty({ example: '2025-09-13T12:34:56.789Z' }) updatedAt!: Date;
}

export class OkItemProductDto {
  @ApiProperty({ example: true }) ok!: true;
  @ApiProperty({ type: () => ProductDto }) data!: ProductDto;
}

export class OkListProductDto {
  @ApiProperty({ example: true }) ok!: true;
  @ApiProperty({ type: () => [ProductDto] }) data!: ProductDto[];
}

/** 페이지네이션 응답 */
export class ProductPageDto {
  @ApiProperty({ type: () => [ProductDto] }) items!: ProductDto[];
  @ApiProperty({ example: 1 }) page!: number;
  @ApiProperty({ example: 20 }) limit!: number;
  @ApiProperty({ example: 42 }) total!: number;
  @ApiProperty({ example: 3 }) pages!: number;
}

export class OkPageProductDto {
  @ApiProperty({ example: true }) ok!: true;
  @ApiProperty({ type: () => ProductPageDto }) data!: ProductPageDto;
}

export class DeleteResultDto {
  @ApiProperty({ example: true }) deleted!: true;
  @ApiProperty({ example: 'uuid' }) id!: string;
}
