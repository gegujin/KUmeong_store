// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\products\products.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DeepPartial, Repository } from 'typeorm';
import { Product, ProductStatus } from './entities/product.entity';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { QueryProductDto } from './dto/query-product.dto';
// import { User } from '../users/entities/user.entity'; // ❌ 사용 안 함 → 제거

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(Product)
    private readonly repo: Repository<Product>,
  ) {}

  /** 목록: 페이지네이션/정렬/검색/필터 (+ deletedAt 필터 기본 적용) */
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
      .where('p.deletedAt IS NULL');

    const status = (q?.status as ProductStatus) ?? ProductStatus.LISTED;
    qb.andWhere('p.status = :status', { status });

    if (q?.q) {
      qb.andWhere('(p.title LIKE :kw OR p.description LIKE :kw OR p.category LIKE :kw)', {
        kw: `%${q.q}%`,
      });
    }
    if (q?.category) qb.andWhere('p.category = :category', { category: q.category });
    if (q?.priceWonMin != null) qb.andWhere('p.priceWon >= :min', { min: Number(q.priceWonMin) });
    if (q?.priceWonMax != null) qb.andWhere('p.priceWon <= :max', { max: Number(q.priceWonMax) });

    qb.orderBy(`p.${orderField}`, orderDir)
      .addOrderBy('p.id', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);

    const [items, total] = await qb.getManyAndCount();
    const pages = Math.max(1, Math.ceil(total / limit));
    return { items, page, limit, total, pages };
  }

  /** 단건 조회: 소프트 삭제된 레코드는 404 */
  async findOne(id: string): Promise<Product> {
    const row = await this.repo.findOne({ where: { id } });
    if (!row || row.deletedAt) throw new NotFoundException('Product not found');
    return row;
  }

  /** 생성: sellerId는 인증 사용자(me.id)로 주입 */
  async create(sellerId: string, dto: CreateProductDto): Promise<Product> {
    const entity = this.repo.create({
      title: dto.title,
      priceWon: dto.priceWon,
      category: dto.category,
      description: dto.description,
      status: dto.status ?? ProductStatus.LISTED,
      sellerId, // ✅ 서버 주입
    } as DeepPartial<Product>);

    return this.repo.save(entity);
  }

  /** 수정: 소프트 삭제된 레코드는 수정 불가 */
  async update(id: string, dto: UpdateProductDto): Promise<Product> {
    const exists = await this.repo.findOne({ where: { id } });
    if (!exists || exists.deletedAt) throw new NotFoundException('Product not found');

    const merged = this.repo.merge(exists, {
      title: dto.title,
      priceWon: dto.priceWon,
      category: dto.category,
      description: dto.description,
      status: dto.status,
    } as DeepPartial<Product>);

    return this.repo.save(merged);
  }

  /** 삭제: 소프트 삭제 */
  async remove(id: string): Promise<{ deleted: true; id: string }> {
    const exists = await this.repo.findOne({ where: { id } });
    if (!exists || exists.deletedAt) throw new NotFoundException('Product not found');

    await this.repo.update(id, { deletedAt: () => 'CURRENT_TIMESTAMP' });
    return { deleted: true, id };
  }
}
