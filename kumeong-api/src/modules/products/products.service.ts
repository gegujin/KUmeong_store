// src/modules/products/products.service.ts
import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DeepPartial, Repository } from 'typeorm';
import { Product, ProductStatus } from './entities/product.entity';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { QueryProductDto } from './dto/query-product.dto';

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(Product)
    private readonly repo: Repository<Product>,
  ) {}

  /** 목록: 페이지네이션/정렬/검색/필터 */
  async findAll(
    q: QueryProductDto,
  ): Promise<{ items: Product[]; page: number; limit: number; total: number; pages: number }> {
    const page = Math.max(1, Number(q?.page ?? 1));
    const limit = Math.min(100, Math.max(1, Number(q?.limit ?? 20)));

    // 정렬 필드/방향 화이트리스트
    const allowedSort: Array<keyof Product> = ['createdAt', 'price', 'title'];
    const orderField = (allowedSort.includes(q?.sort as any) ? q?.sort : 'createdAt') as
      | 'createdAt'
      | 'price'
      | 'title';
    const orderDir: 'ASC' | 'DESC' =
      ((q?.order ?? 'DESC').toString().toUpperCase() === 'ASC' ? 'ASC' : 'DESC');

    const qb = this.repo.createQueryBuilder('p').where('1=1');

    if (q?.q) qb.andWhere('(p.title LIKE :kw OR p.description LIKE :kw)', { kw: `%${q.q}%` });
    if (q?.category) qb.andWhere('p.category = :category', { category: q.category });
    if (q?.status) qb.andWhere('p.status = :status', { status: q.status as ProductStatus });
    if (q?.priceMin != null) qb.andWhere('p.price >= :min', { min: Number(q.priceMin) });
    if (q?.priceMax != null) qb.andWhere('p.price <= :max', { max: Number(q.priceMax) });

    qb.orderBy(`p.${orderField}`, orderDir).skip((page - 1) * limit).take(limit);

    const [items, total] = await qb.getManyAndCount();
    const pages = Math.max(1, Math.ceil(total / limit));
    return { items, page, limit, total, pages };
  }

  /** 단건 조회 (PK는 uuid 문자열) */
  async findOne(id: string): Promise<Product> {
    const item = await this.repo.findOne({ where: { id } });
    if (!item) throw new NotFoundException('Product not found');
    return item;
  }

  /** 생성: ownerId는 컨트롤러에서 @CurrentUser로 받아 주입 (User.id:number) */
  async createProduct(ownerId: number | string, dto: CreateProductDto): Promise<Product> {
    const ownerIdNum = Number(ownerId);
    if (!Number.isFinite(ownerIdNum)) {
      throw new BadRequestException('ownerId must be a number');
    }

    // create/save 단건 오버로드로 사용
    const entity = this.repo.create({
      ...(dto as unknown as DeepPartial<Product>),
      ownerId: ownerIdNum,
    });

    return this.repo.save(entity);
  }

  /** ✅ 컨트롤러 호환용 래퍼: (dto, ownerId) 순서 */
  async createWithOwner(dto: CreateProductDto, ownerId: number | string): Promise<Product> {
    return this.createProduct(ownerId, dto);
  }

  /** 수정 */
  async update(id: string, dto: UpdateProductDto): Promise<Product> {
    const exists = await this.repo.findOne({ where: { id } });
    if (!exists) throw new NotFoundException('Product not found');
    const merged = this.repo.merge(exists, dto as DeepPartial<Product>);
    return this.repo.save(merged);
  }

  /** 삭제 */
  async remove(id: string): Promise<{ deleted: true; id: string }> {
    const exists = await this.repo.findOne({ where: { id } });
    if (!exists) throw new NotFoundException('Product not found');
    await this.repo.delete(id);
    return { deleted: true, id };
  }
}
