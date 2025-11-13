// kumeong-api/src/modules/products/products.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DeepPartial, Repository } from 'typeorm';
import { Product, ProductStatus } from './entities/product.entity';
import { ProductImage } from './entities/product-image.entity';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { QueryProductDto } from './dto/query-product.dto';

// 업로드 파일 최소 타입(런타임 영향 없음)
type MulterFile = {
  fieldname: string;
  originalname: string;
  encoding: string;
  mimetype: string;
  size: number;
  destination?: string;
  filename?: string;
  path?: string;
  buffer?: Buffer;
};

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(Product)
    private readonly repo: Repository<Product>,
    @InjectRepository(ProductImage)
    private readonly imgRepo: Repository<ProductImage>,
  ) {}

  /** 목록: 페이지네이션/정렬/검색/필터 (+ deletedAt IS NULL 기본) */
  async findAll(
    q: QueryProductDto,
  ): Promise<{ items: Product[]; page: number; limit: number; total: number; pages: number }> {
    const page = Math.max(1, Number(q?.page ?? 1));
    const limit = Math.min(100, Math.max(1, Number(q?.limit ?? 20)));

    const allowedSort: Array<'createdAt' | 'priceWon' | 'title'> = ['createdAt', 'priceWon', 'title'];
    const orderField = (allowedSort.includes(q?.sort as any) ? (q?.sort as any) : 'createdAt') as
      | 'createdAt'
      | 'priceWon'
      | 'title';
    const orderDir: 'ASC' | 'DESC' =
      ((q?.order ?? 'DESC').toString().toUpperCase() === 'ASC' ? 'ASC' : 'DESC');

    const qb = this.repo
      .createQueryBuilder('p')
      .leftJoinAndSelect('p.images', 'img')
      .where('p.deletedAt IS NULL');

    // 상태(미지정 시 LISTED)
    const status = (q?.status as ProductStatus) ?? ProductStatus.LISTED;
    qb.andWhere('p.status = :status', { status });

    // 키워드 검색(제목/설명/카테고리경로/위치텍스트)
    if (q?.q) {
      qb.andWhere(
        '(p.title LIKE :kw OR p.description LIKE :kw OR p.categoryPath LIKE :kw OR p.locationText LIKE :kw)',
        { kw: `%${q.q}%` },
      );
    }

    // --- 카테고리 필터 (신/구 파라미터 호환) ---
    // 신: categoryPath / categoryPathPrefix
    // 구: category / categoryPrefix
    const catExactRaw =
      (q as any)?.categoryPath ??
      (q as any)?.category ??
      undefined;
    const catExact = typeof catExactRaw === 'string' ? catExactRaw.trim() : undefined;

    const catPrefixRaw =
      (q as any)?.categoryPathPrefix ??
      (q as any)?.categoryPrefix ??
      undefined;
    const catPrefix =
      catExact ? undefined : (typeof catPrefixRaw === 'string' ? catPrefixRaw.trim() : undefined);

    if (catExact) {
      qb.andWhere('p.categoryPath = :categoryPath', { categoryPath: catExact });
    } else if (catPrefix) {
      // %, _, \ 이스케이프 → 접두사 매칭
      const esc = catPrefix.replace(/([%_\\])/g, '\\$1');
      const pref = `${esc}%`;
      qb.andWhere("p.categoryPath LIKE :pref ESCAPE '\\\\'", { pref });
    }

    // 가격 범위
    if (q?.priceWonMin != null) qb.andWhere('p.priceWon >= :min', { min: Number(q.priceWonMin) });
    if (q?.priceWonMax != null) qb.andWhere('p.priceWon <= :max', { max: Number(q.priceWonMax) });

    qb.orderBy(`p.${orderField}`, orderDir)
      .addOrderBy('p.id', 'DESC')
      .addOrderBy('img.ord', 'ASC')
      .skip((page - 1) * limit)
      .take(limit);

    const [items, total] = await qb.getManyAndCount();
    const pages = Math.max(1, Math.ceil(total / limit));
    return { items, page, limit, total, pages };
  }

  /** 단건 조회: 소프트 삭제된 레코드는 404 */
  async findOne(id: string): Promise<Product> {
    const row = await this.repo
      .createQueryBuilder('p')
      .leftJoinAndSelect('p.images', 'img')
      .where('p.id = :id', { id })
      .andWhere('p.deletedAt IS NULL')
      .orderBy('img.ord', 'ASC')
      .getOne();

    if (!row) throw new NotFoundException('Product not found');
    return row;
  }

  /**
   * 생성: sellerId는 인증 사용자(me.id)로 주입
   * images는 선택(컨트롤러에서 FileFieldsInterceptor로 수신)
   */
  async create(
    sellerId: string,
    dto: CreateProductDto,
    images: MulterFile[] = [],
  ): Promise<Product> {
    const entity = this.repo.create({
      title: dto.title,
      priceWon: dto.priceWon,
      categoryPath: dto.categoryPath,
      locationText: dto.locationText,
      description: dto.description,
      status: ProductStatus.LISTED,
      sellerId,
    } as DeepPartial<Product>);

    const saved = await this.repo.save(entity);

    // 업로드 이미지 저장
    if (images && images.length > 0) {
      const rows = images
        .map((f, idx) => {
          const url =
            f?.filename
              ? `/uploads/${f.filename}`
              : (f?.path && f.path.includes('/uploads/'))
                ? f.path.slice(f.path.indexOf('/uploads/'))
                : '';
          if (!url) return null; // 빈 URL은 저장 스킵
          return this.imgRepo.create({
            productId: saved.id,
            url,
            ord: idx,
          });
        })
        .filter((v): v is ProductImage => !!v);
      await this.imgRepo.save(rows);

      // 이미지 포함 재조회(정렬 포함)
      const withImgs = await this.repo
        .createQueryBuilder('p')
        .leftJoinAndSelect('p.images', 'img')
        .where('p.id = :id', { id: saved.id })
        .orderBy('img.ord', 'ASC')
        .getOne();

      return withImgs ?? saved;
    }

    return saved;
  }

  /** 수정: 소프트 삭제된 레코드는 수정 불가 */
  async update(id: string, dto: UpdateProductDto): Promise<Product> {
    const exists = await this.repo.findOne({ where: { id } });
    if (!exists || exists.deletedAt) throw new NotFoundException('Product not found');

    const merged = this.repo.merge(exists, {
      title: dto.title ?? exists.title,
      priceWon: dto.priceWon ?? exists.priceWon,
      categoryPath: (dto as any).categoryPath ?? (exists as any).categoryPath,
      locationText: (dto as any).locationText ?? (exists as any).locationText,
      description: dto.description ?? exists.description,
      status: dto.status ?? exists.status,
    } as DeepPartial<Product>);

    return this.repo.save(merged);
  }

  /** 삭제: 소프트 삭제 */
  async remove(id: string): Promise<{ deleted: true; id: string }> {
    const exists = await this.repo.findOne({ where: { id } });
    if (!exists || exists.deletedAt) throw new NotFoundException('Product not found');

    await this.repo.update(id, { deletedAt: () => 'CURRENT_TIMESTAMP' } as any);
    return { deleted: true, id };
  }

  async incrementViews(id: string): Promise<number> {
    // id 존재 확인 (없으면 404)
    const exists = await this.repo.exists({ where: { id } });
    if (!exists) throw new NotFoundException('Product not found');

    // views = views + 1 (원자적 증가)
    await this.repo
      .createQueryBuilder()
      .update(Product)
      .set({ views: () => 'views + 1' })
      .where('id = :id', { id })
      .execute();

    // 최신 값 반환
    const fresh = await this.repo.findOne({
      where: { id },
      select: ['id', 'views'],
    });
    return fresh?.views ?? 0;
  }
}
