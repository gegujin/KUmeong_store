// src/modules/auth/auth.controller.ts
import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  UseGuards,
  HttpCode,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';
import { Request } from 'express';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from './auth.service';

class RegisterDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(4) password!: string;
  @IsString() @IsOptional() name?: string;
}

class LoginDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(4) password!: string;
}

@ApiTags('auth')
// URI 버전닝과 정확히 매칭: /api/v1/auth/...
@Controller({ path: 'auth', version: '1' })
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @ApiOperation({ summary: '회원가입' })
  @Post('register') // POST /api/v1/auth/register
  @HttpCode(200)
  async register(@Body() dto: RegisterDto) {
    const { accessToken, refreshToken, user } = await this.auth.register(dto);
    return { ok: true, data: { accessToken, refreshToken, user } };
  }

  @ApiOperation({ summary: '로그인' })
  @Post('login') // POST /api/v1/auth/login
  @HttpCode(200)
  async login(@Body() dto: LoginDto) {
    const { accessToken, refreshToken, user } = await this.auth.login(
      dto.email,
      dto.password,
    );
    return { ok: true, data: { accessToken, refreshToken, user } };
  }

  @ApiOperation({ summary: '토큰 재발급(리프레시)' })
  @Post('refresh') // POST /api/v1/auth/refresh
  @HttpCode(200)
  async refresh(@Body() dto: { refreshToken: string }) {
    const { accessToken, refreshToken, user } = await this.auth.refresh(dto as any);
    return { ok: true, data: { accessToken, refreshToken, user } };
  }

  @ApiOperation({ summary: '내 정보' })
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @Get('me') // GET /api/v1/auth/me
  async me(@Req() req: Request) {
    const user = req.user as { id: string; email?: string; role?: string } | undefined;
    return { ok: true, user };
  }
}
