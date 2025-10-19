// kumeong-api/src/modules/products/dto/find-products.dto.ts  (없다면 추가)
import { IsOptional, IsString, MaxLength } from 'class-validator';

export class FindProductsDto {
  @IsOptional() @IsString() query?: string;
  @IsOptional() @IsString() @MaxLength(50) category?: string;
  // 필요시 minPrice, maxPrice, sort, page, limit 등...
}
