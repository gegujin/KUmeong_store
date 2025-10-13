// src/modules/auth/auth.controller.ts
import { Body, Controller, Get, Post, UseGuards, HttpCode, VERSION_NEUTRAL } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiBody, ApiOperation, ApiOkResponse, ApiUnauthorizedResponse } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto'; // { refreshToken: string }
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { CurrentUser } from './decorators/current-user.decorator';
import type { SafeUser } from './types/user.types';
import { Public } from './decorators/public.decorator';

@ApiTags('Auth')
// ✅ 버전 중립으로 변경: 헤더 없이도 /api/auth/* 매칭
@Controller({ path: 'auth', version: '1' })
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  // ========== REGISTER ==========
  @Public()
  @Post('register')
  @HttpCode(200)
  @ApiOperation({ summary: '회원가입 + 액세스/리프레시 토큰 발급' })
  @ApiBody({
    type: RegisterDto,
    examples: {
      sample: {
        summary: '예시',
        value: {
          email: 'student@kku.ac.kr',
          name: 'KKU Student',
          password: 'password1234',
        },
      },
    },
  })
  @ApiOkResponse({
    description: '가입 성공',
    schema: {
      example: {
        ok: true,
        data: {
          accessToken: 'eyJhbGciOi...',
          refreshToken: 'eyJhbGciOi...',
          user: {
            id: 'uuid',
            email: 'student@kku.ac.kr',
            name: 'KKU Student',
            role: 'USER',
          },
        },
      },
    },
  })
  async register(@Body() dto: RegisterDto) {
    const result = await this.auth.register(dto);
    return { ok: true, data: result };
  }

  // ========== LOGIN ==========
  @Public()
  @Post('login')
  @HttpCode(200)
  @ApiOperation({ summary: '로그인 + 액세스/리프레시 토큰 발급' })
  @ApiBody({
    type: LoginDto,
    examples: {
      sample: {
        summary: '예시',
        value: {
          email: 'student@kku.ac.kr',
          password: 'password1234',
        },
      },
    },
  })
  @ApiOkResponse({
    description: '로그인 성공',
    schema: {
      example: {
        ok: true,
        data: {
          accessToken: 'eyJhbGciOi...',
          refreshToken: 'eyJhbGciOi...',
          user: {
            id: 'uuid',
            email: 'student@kku.ac.kr',
            name: 'KKU Student',
            role: 'USER',
          },
        },
      },
    },
  })
  @ApiUnauthorizedResponse({
    description: '잘못된 자격 증명',
    schema: {
      example: {
        ok: false,
        error: { code: 401, message: 'INVALID_CREDENTIALS' },
        // ✅ 경로 예시도 /api/auth/login 로 정정
        path: '/api/auth/login',
        timestamp: '2025-10-08T12:34:56.789Z',
      },
    },
  })
  async login(@Body() dto: LoginDto) {
    const result = await this.auth.login(dto);
    return { ok: true, data: result };
  }

  // ========== REFRESH ==========
  @Public()
  @Post('refresh')
  @HttpCode(200)
  @ApiOperation({ summary: '리프레시 토큰으로 액세스 토큰 재발급' })
  @ApiBody({
    type: RefreshDto,
    examples: {
      sample: {
        summary: '예시',
        value: { refreshToken: 'eyJhbGciOi...' },
      },
    },
  })
  @ApiOkResponse({
    description: '재발급 성공',
    schema: {
      example: { ok: true, data: { accessToken: 'eyJhbGciOi...' } },
    },
  })
  @ApiUnauthorizedResponse({
    description: '리프레시 토큰 누락/만료/폐기',
  })
  async refresh(@Body() dto: RefreshDto) {
    const accessToken = await this.auth.refresh(dto.refreshToken);
    return { ok: true, data: { accessToken } };
  }

  // ========== ME ==========
  @Get('me')
  @ApiOperation({ summary: '현재 사용자 정보 조회 (JWT 필요)' })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOkResponse({
    schema: {
      example: {
        ok: true,
        data: {
          user: {
            id: 'uuid',
            email: 'student@kku.ac.kr',
            name: 'KKU Student',
            role: 'USER',
          },
        },
      },
    },
  })
  @ApiUnauthorizedResponse({ description: 'JWT 누락/유효하지 않음' })
  me(@CurrentUser() user: SafeUser) {
    return { ok: true, data: { user } };
  }
}
