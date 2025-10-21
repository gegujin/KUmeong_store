import { IsEnum, IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { ProductStatus } from '../entities/product.entity';

export class QueryProductDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit = 20;
  @IsOptional() @IsIn(['createdAt','price','title']) sort: 'createdAt'|'price'|'title' = 'createdAt';
  @IsOptional() @IsIn(['ASC','DESC']) order: 'ASC'|'DESC' = 'DESC';
  @IsOptional() @IsString() q?: string;
  @IsOptional() @IsString() category?: string;
  @IsOptional() @Type(() => Number) @IsInt() priceMin?: number;
  @IsOptional() @Type(() => Number) @IsInt() priceMax?: number;
  @IsOptional() @IsEnum(ProductStatus) status?: ProductStatus;
}
