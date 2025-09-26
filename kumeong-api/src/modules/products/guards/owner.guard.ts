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
    const user = req.user as { id: string; role?: UserRole } | undefined;
    const id = req.params?.id as string | undefined;

    if (!id) throw new ForbiddenException('Missing product id');

    const p = await this.products.findOne({
      where: { id },
      select: { id: true, ownerId: true },
    });
    if (!p) throw new NotFoundException('Product not found');

    if (!user) throw new ForbiddenException('Unauthorized');

    if (user.role === UserRole.ADMIN) return true; // 관리자 우회
    const userIdNum = Number(user.id); // SafeUser.id가 string일 수 있어서 변환
    if (!Number.isFinite(userIdNum)) {
      throw new ForbiddenException('잘못된 사용자 식별자');
    }
    if (p.ownerId !== userIdNum) {
      throw new ForbiddenException('본인 상품만 변경할 수 있습니다.');
    }
    return true;
  }
}
