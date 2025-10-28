// src/modules/delivery/delivery.controller.ts
import { Controller, Get, Post, Body, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { DeliveryService } from './delivery.service';
import { SignupDto } from './dto/signup.dto';

@ApiTags('delivery')
@ApiBearerAuth()
@Controller({ path: 'delivery', version: '1' })
@UseGuards(JwtAuthGuard)
export class DeliveryController {
  constructor(private readonly service: DeliveryService) {}

  /**
   * ✅ 진단용 프로브: DB 접근 금지
   * 가드(JWT)만 통과하면 바로 200 + 현재 사용자 페이로드 반환
   */
  // ✅ 실제 DB 확인: isMember/transport 반환
  @Get('membership')
  async membership(@Req() req: any) {
    const me: string = req.user?.id ?? req.user?.sub;
    const res = await this.service.getMembership(me);
    return { ok: true, ...res }; // { ok:true, isMember:boolean, transport?:string|null }
  }

  /**
   * 실제 가입 로직은 그대로 서비스 호출
   * req.user.id 없을 때를 대비해 sub도 허용
   */
  @Post('signup')
  async signup(@Req() req: any, @Body() dto: SignupDto) {
    const me: string | undefined = req.user?.id ?? req.user?.sub;
    // 여기서 me가 없으면 가드가 잘못된 것이므로 방어적으로 한 줄 넣고 싶다면:
    // if (!me) throw new UnauthorizedException('No user in request');
    const res = await this.service.signup(me as string, dto);
    return { ok: true, ...res };
  }
}
