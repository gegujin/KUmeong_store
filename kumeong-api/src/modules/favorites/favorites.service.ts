// src/modules/favorites/favorites.service.ts
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
    @InjectRepository(Product)  private readonly prodRepo: Repository<Product>,
    private readonly ds: DataSource,
  ) {}

  /**
   * 하트(찜) 토글
   * - 결과에 isFavorited + favoriteCount(총 찜수) 반환
   * - 유니크 충돌(1062)도 안전 처리
   */
  async toggle(meId: string, productId: string) {
    // 상품 존재 확인
    const p = await this.prodRepo.findOne({ where: { id: productId } });
    if (!p) throw new NotFoundException('상품을 찾을 수 없습니다.');

    // 기존 여부 확인
    const exists = await this.favRepo.findOne({ where: { ownerUserId: meId, productId } });

    if (exists) {
      await this.favRepo.delete({ ownerUserId: meId, productId });
      const favoriteCount = await this.favRepo.count({ where: { productId } });
      return { isFavorited: false, favoriteCount, productId };
    }

    // 신규 저장 (유니크 충돌 방지)
    try {
      await this.favRepo.save({
        id: uuidv4(),
        ownerUserId: meId,
        productId,
      });
    } catch (e: any) {
      // MySQL: ER_DUP_ENTRY (1062) → 이미 찜 상태로 간주
      if (!(e?.code === 'ER_DUP_ENTRY' || e?.errno === 1062)) {
        throw e;
      }
    }

    const favoriteCount = await this.favRepo.count({ where: { productId } });
    return { isFavorited: true, favoriteCount, productId };
  }

  /** 내가 찜한 상품 리스트 (상품 카드와 동일하게 products 포맷 가깝게 반환) */
  async listMine(meId: string, page = 1, limit = 20) {
    const offset = (page - 1) * limit;

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
        'f.createdAt    AS f_createdAt', // 정렬 컬럼
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

    const normalized = items.map((r: any) => ({
      id: r.id,
      title: r.title,
      priceWon: Number(r.priceWon ?? r.pricewon ?? 0),
      status: r.status,
      description: r.description,
      category: r.category,
      images: Array.isArray(r.images)
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
    }));

    return {
      items: normalized,
      total: Number(totalRow?.cnt ?? 0),
      page,
      limit,
    };
  }
}
