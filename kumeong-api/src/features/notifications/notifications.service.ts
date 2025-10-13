// C:\Users\82105\KU-meong Store\kumeong-api\src\features\notifications\notifications.service.ts
import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull, FindOptionsWhere } from 'typeorm'; // ← IsNull, FindOptionsWhere 추가
import { NotificationEntity, NotificationType } from './entities/notification.entity';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(NotificationEntity)
    private readonly repo: Repository<NotificationEntity>,
  ) {}

  async create(userId: number, type: NotificationType, payload?: Record<string, any>) {
    const e = this.repo.create({ userId, type, payload: payload ?? null });
    await this.repo.save(e);
    return e.id;
  }

  async list(me: number, onlyUnread = false) {
    const where: FindOptionsWhere<NotificationEntity> =
      onlyUnread ? { userId: me, readAt: IsNull() } : { userId: me }; // ← 여기!

    return this.repo.find({
      where,
      order: { readAt: 'ASC', createdAt: 'DESC' },
      take: 100,
    });
  }

  async markRead(me: number, id: number) {
    const n = await this.repo.findOne({ where: { id } });
    if (!n) throw new NotFoundException();
    if (n.userId !== me) throw new ForbiddenException();
    if (!n.readAt) {
      n.readAt = new Date();
      await this.repo.save(n);
    }
  }

  async remove(me: number, id: number) {
    const n = await this.repo.findOne({ where: { id } });
    if (!n) throw new NotFoundException();
    if (n.userId !== me) throw new ForbiddenException();
    await this.repo.remove(n);
  }
  
  async countUnread(me: number) {
    return this.repo.count({ where: { userId: me, readAt: IsNull() } });
  }

  async markAllRead(me: number) {
    await this.repo
      .createQueryBuilder()
      .update(NotificationEntity)
      .set({ readAt: () => 'CURRENT_TIMESTAMP' }) // SQLite/MySQL 모두 OK
      .where('userId = :me AND readAt IS NULL', { me })
      .execute();
  }
}
