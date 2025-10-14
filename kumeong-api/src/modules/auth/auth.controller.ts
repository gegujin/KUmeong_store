// src/modules/auth/auth.controller.ts
import { Body, Controller, Get, Post, Req, UseGuards, HttpCode } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { RefreshDto } from './dto/refresh.dto';
import { IsEmail, IsString, MinLength } from 'class-validator';
import { Request } from 'express';
import { AuthGuard } from '@nestjs/passport';

class LoginDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(4) password!: string;
}

@ApiTags('auth')
@Controller('auth') // ✅ 버전 제거: 글로벌 defaultVersion('1') 사용
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @ApiOperation({ summary: '로그인' })
  @Post('login')
  @HttpCode(200)
  async login(@Body() dto: LoginDto) {
    const { accessToken, refreshToken, user } = await this.auth.login(dto.email, dto.password);
    return { ok: true, data: { accessToken, refreshToken, user } };
  }

  @ApiOperation({ summary: '토큰 재발급(리프레시)' })
  @Post('refresh')
  @HttpCode(200)
  async refresh(@Body() dto: RefreshDto) {
    const { accessToken, refreshToken, user } = await this.auth.refresh(dto);
    return { ok: true, data: { accessToken, refreshToken, user } };
  }

  @ApiOperation({ summary: '내 정보' })
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('me')
  async me(@Req() req: Request) {
    const user = req.user as { id: string; email?: string; role?: string } | undefined;
    return { ok: true, user };
  }
}
