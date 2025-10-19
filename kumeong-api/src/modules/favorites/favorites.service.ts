// favorites.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Favorite } from './entities/favorite.entity';
import { v4 as uuidv4 } from 'uuid';
import { Product } from '../products/entities/product.entity';

@Injectable()
export class FavoritesService {
  constructor(
    @InjectRepository(Favorite) private readonly favRepo: Repository<Favorite>,
    @InjectRepository(Product) private readonly prodRepo: Repository<Product>,
    private readonly ds: DataSource, // ✅ 추가
  ) {}

  async toggle(meId: string, productId: string) {
    const exists = await this.favRepo.findOne({ where: { ownerUserId: meId, productId } });
    if (exists) {
      await this.favRepo.delete({ ownerUserId: meId, productId });
      return { isFavorited: false };
    }
    const p = await this.prodRepo.findOne({ where: { id: productId } });
    if (!p) throw new NotFoundException('상품을 찾을 수 없습니다.');
    await this.favRepo.save({
      id: uuidv4(),
      ownerUserId: meId,
      productId,
    });
    return { isFavorited: true };
  }

  /** 내가 찜한 상품 리스트 (상품 카드와 동일하게 products 그대로 반환) */
  async listMine(meId: string, page = 1, limit = 20) {
    const offset = (page - 1) * limit;

    // ✅ raw SQL/QueryBuilder로 안전하게: DISTINCT 회피 + 정렬컬럼 명시선택
    const items = await this.ds
      .createQueryBuilder()
      .from('favorites', 'f')
      .innerJoin('products', 'p', 'p.id = f.productId')
      .select([
        'p.id           AS id',
        'p.title        AS title',
        'p.priceWon     AS priceWon',
        'p.status       AS status',
        'p.description  AS description',
        'p.category     AS category',
        'p.images       AS images',
        'p.sellerId     AS sellerId',
        'p.createdAt    AS createdAt',
        'p.updatedAt    AS updatedAt',
        'p.deletedAt    AS deletedAt',
        'p.locationText AS locationText',
        // ⬇⬇ 정렬 컬럼은 반드시 select에 포함시키기
        'f.createdAt    AS f_createdAt',
      ])
      .where('f.ownerUserId = :uid', { uid: meId })
      .orderBy('f.createdAt', 'DESC')
      .offset(offset)
      .limit(limit)
      .getRawMany();

    const totalRow = await this.ds
      .createQueryBuilder()
      .from('favorites', 'f')
      .select('COUNT(*)', 'cnt')
      .where('f.ownerUserId = :uid', { uid: meId })
      .getRawOne();

    // images(Text) → 배열로 파싱, 프론트 호환 필드 유지
    const normalized = items.map((r: any) => ({
      id: r.id,
      title: r.title,
      priceWon: Number(r.priceWon ?? r.pricewon ?? 0),
      status: r.status,
      description: r.description,
      category: r.category,
      images:
        Array.isArray(r.images)
          ? r.images
          : (typeof r.images === 'string' && r.images.trim().startsWith('[')
              ? JSON.parse(r.images)
              : []),
      sellerId: r.sellerId ?? r.sellerid,
      createdAt: r.createdAt ?? r.createdat,
      updatedAt: r.updatedAt ?? r.updatedat,
      deletedAt: r.deletedAt ?? r.deletedat,
      locationText: r.locationText ?? r.locationtext,
      isFavorited: true,
      // 필요시 썸네일 계산은 컨트롤러/서비스에서 추가 가능
    }));

    return {
      items: normalized,
      total: Number(totalRow?.cnt ?? 0),
      page,
      limit,
    };
  }
}
