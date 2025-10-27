// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\products\guards\owner.guard.ts
import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Product } from '../entities/product.entity';
import { UserRole } from '../../users/entities/user.entity';

@Injectable()
export class OwnerGuard implements CanActivate {
  constructor(
    @InjectRepository(Product)
    private readonly products: Repository<Product>,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest();
    const user = (req.user as { id: string; role?: UserRole } | undefined) ?? undefined;

    // 경로 파라미터에서 상품 ID
    const productId = (req.params?.id as string | undefined) ?? undefined;
    if (!productId) throw new ForbiddenException('Missing product id');

    // 상품 존재 확인 (소유자만 조회)
    const p = await this.products.findOne({
      where: { id: productId },
      select: { id: true, sellerId: true },
    });
    if (!p) throw new NotFoundException('Product not found');

    // 사용자 인증 확인
    const headerUserId = req.header?.('X-User-Id') || req.headers?.['x-user-id'];
    const meId = (user?.id ?? headerUserId ?? '').toString().toLowerCase();
    if (!meId) throw new ForbiddenException('Unauthorized');

    // 관리자 우회
    if (user?.role === UserRole.ADMIN) return true;

    // UUID 문자열 비교
    if (p.sellerId.toLowerCase() !== meId) {
      throw new ForbiddenException('본인 상품만 변경할 수 있습니다.');
    }

    return true;
  }
}
