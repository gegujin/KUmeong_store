import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { ProductStatus } from '../entities/product.entity';

export class CreateProductDto {
  @ApiProperty({ example: '과잠', maxLength: 100, description: '상품 제목' })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MaxLength(100)
  title!: string;

  @ApiProperty({ example: 1000, minimum: 0, description: '가격(정수)' })
  @Transform(({ value }) => {
    if (value === null || value === undefined || value === '') return 0;

    // 문자열이라면 쉼표/공백 제거 후 숫자로 변환
    const n =
      typeof value === 'string'
        ? Number(value.replace(/[, ]/g, ''))
        : Number(value);

    // 유효하지 않거나 음수면 0 반환
    if (!Number.isFinite(n) || n < 0) return 0;

    // 정수 강제 변환 (소수점 제거)
    return Math.floor(n);
  })
  @IsInt({ message: 'priceWon must be an integer number' })
  @Min(0, { message: 'priceWon must not be less than 0' })
  priceWon!: number;

  @ApiPropertyOptional({ example: '거의 새상품입니다.', description: '상품 설명' })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: '모시래', description: '거래 위치/카테고리' })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsOptional()
  @IsString()
  category?: string;

  @ApiPropertyOptional({
    example: '의류/패션>남성의류',
    description: '태그',
  })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsOptional()
  @IsString()
  tags?: string;

  @ApiPropertyOptional({
    enum: ProductStatus,
    example: ProductStatus.ON_SALE, // ✅ enum 키 ON_SALE 사용
  })
  @IsOptional()
  @IsEnum(ProductStatus)
  status?: ProductStatus;

  @ApiPropertyOptional({ example: '서울시 성북구', description: '거래 위치' })
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsOptional()
  @IsString()
  location?: string;
}
