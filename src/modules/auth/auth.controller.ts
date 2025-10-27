// src/modules/auth/auth.controller.ts
import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  UseGuards,
  HttpCode,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsBoolean, IsEmail, IsOptional, IsString, MinLength, MaxLength } from 'class-validator';
import { Request } from 'express';
import { AuthGuard } from '@nestjs/passport';
import { AuthService } from './auth.service';

// DTO들: 비밀번호는 '문자열'로, 폭넓은 길이 허용
class RegisterDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(4) @MaxLength(128) password!: string;
  @IsString() @IsOptional() name?: string;
}

class LoginDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(4) @MaxLength(128) password!: string;
}

class RefreshBodyDto {
  @IsString() @MinLength(10) @MaxLength(4096) refreshToken!: string;
}

// ✅ 변경: dev reset DTO에 confirm 플래그 추가 (실수 방지)
class DevResetDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(4) @MaxLength(128) newPassword!: string;
  @IsBoolean() @IsOptional() confirm?: boolean; // true 여야만 실행
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
    const { accessToken, refreshToken, user } =
      await this.auth.login(dto.email, dto.password);
    return { ok: true, data: { accessToken, refreshToken, user } };
  }

  @ApiOperation({ summary: '토큰 재발급(리프레시)' })
  @Post('refresh') // POST /api/v1/auth/refresh
  @HttpCode(200)
  async refresh(@Body() dto: RefreshBodyDto) {
    const { accessToken, refreshToken, user } =
      await this.auth.refresh(dto as any);
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

  @ApiOperation({ summary: '[DEV] 비밀번호 재설정 (개발 모드 전용)' })
  @Post('dev/reset-password') // POST /api/v1/auth/dev/reset-password
  @HttpCode(200)
  async devResetPassword(@Body() dto: DevResetDto) {
    const isDev = process.env.NODE_ENV === 'development';
    if (!isDev) {
      throw new ForbiddenException('dev only');
    }

    // ✅ confirm=true 요구 (실수 방지)
    if ((dto as any).confirm !== true) {
      throw new BadRequestException('confirm=true required');
    }

    await this.auth.resetPasswordDev(dto.email, dto.newPassword);

    return { ok: true };
  }
}
