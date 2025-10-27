import { Entity, PrimaryColumn } from 'typeorm';

@Entity({ name: 'chatRoomMembers', synchronize: false })
export class ChatRoomMember {
  @PrimaryColumn('char', { length: 36 })
  roomId!: string;

  @PrimaryColumn('char', { length: 36 })
  userId!: string;
}
