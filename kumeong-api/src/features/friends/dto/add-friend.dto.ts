import { ApiProperty } from '@nestjs/swagger';
import { IsEmail } from 'class-validator';

export class AddFriendDto {
  @ApiProperty({ example: '11@kku.ac.kr', description: '친구 이메일' })
  @IsEmail()
  peerEmail!: string;
}
