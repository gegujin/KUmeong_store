// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\auth\auth.service.ts
import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { UsersService } from '../users/users.service';
import { UserRole } from '../users/entities/user.entity';
import type { SafeUser } from './types/user.types';
import { RefreshDto } from './dto/refresh.dto';

type JwtPayload = {
  sub: string;   // user id (UUID)
  email: string;
  role: UserRole;
};

@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    private readonly cfg: ConfigService,
  ) {}

  /** 이메일/패스워드 검증 → SafeUser 반환 */
  private async validateUser(email: string, password: string): Promise<SafeUser> {
    const user = await this.users.findByEmailWithHash(email);
    if (!user?.passwordHash) {
      throw new UnauthorizedException('INVALID_CREDENTIALS');
    }
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) throw new UnauthorizedException('INVALID_CREDENTIALS');

    // UsersService의 private 헬퍼를 우회 호출 (프로젝트 기존 구조 유지)
    return (this.users as any)['toSafeUser'](user);
  }

  /** 액세스 토큰 발급 */
  private signAccessToken(payload: JwtPayload): string {
    const secret = this.cfg.get<string>('JWT_ACCESS_SECRET', 'access_secret');
    const expiresIn = this.cfg.get<string>('JWT_ACCESS_EXPIRES_IN', '15m'); // 예: 15m
    return this.jwt.sign(payload, { secret, expiresIn });
  }

  /** 리프레시 토큰 발급 (stateless) */
  private signRefreshToken(payload: Pick<JwtPayload, 'sub'>): string {
    const secret = this.cfg.get<string>('JWT_REFRESH_SECRET', 'refresh_secret');
    const expiresIn = this.cfg.get<string>('JWT_REFRESH_EXPIRES_IN', '14d'); // 예: 14d
    return this.jwt.sign(payload, { secret, expiresIn });
  }

  /** 로그인 */
  async login(
    email: string,
    password: string,
  ): Promise<{ accessToken: string; refreshToken: string; user: SafeUser }> {
    const safe = await this.validateUser(email, password);

    const payload: JwtPayload = {
      sub: String(safe.id),                     // ← 문자열로 정규화
      email: safe.email!,
      role: safe.role! as unknown as UserRole,  // (필요 시 enum 캐스팅)
    };

    const accessToken = this.signAccessToken(payload);
    const refreshToken = this.signRefreshToken({ sub: String(safe.id) }); // ← 문자열

    return { accessToken, refreshToken, user: safe };
  }

  /** 리프레시 (토큰 재발급) */
  async refresh(dto: RefreshDto): Promise<{
    accessToken: string;
    refreshToken: string;
    user: SafeUser;
  }> {
    if (!dto?.refreshToken) {
      throw new BadRequestException('MISSING_REFRESH_TOKEN');
    }

    const secret = this.cfg.get<string>('JWT_REFRESH_SECRET', 'refresh_secret');
    let decoded: { sub?: string | number } | null = null;

    try {
      decoded = this.jwt.verify(dto.refreshToken, { secret }) as any;
    } catch {
      throw new UnauthorizedException('INVALID_REFRESH_TOKEN');
    }

    const userId = decoded?.sub;
    if (userId == null) throw new UnauthorizedException('INVALID_REFRESH_TOKEN');

    const safeUser = await this.users.findOne(String(userId)); // ← 문자열로 조회
    const payload: JwtPayload = {
      sub: String(safeUser.id),                   // ← 문자열 보장
      email: safeUser.email!,
      role: safeUser.role! as unknown as UserRole,
    };

    // 토큰 회전
    const newAccess = this.signAccessToken(payload);
    const newRefresh = this.signRefreshToken({ sub: String(safeUser.id) });

    return { accessToken: newAccess, refreshToken: newRefresh, user: safeUser };
  }
}



// import { Injectable, UnauthorizedException, Logger, ConflictException } from '@nestjs/common';
// import { JwtService } from '@nestjs/jwt';
// import * as bcrypt from 'bcryptjs';
// import { UsersService } from '../users/users.service';
// import { RegisterDto } from './dto/register.dto';
// import { LoginDto } from './dto/login.dto';
// import { ConfigService } from '@nestjs/config';

// import { InjectRepository } from '@nestjs/typeorm';
// import { Repository } from 'typeorm';
// import { User } from '../users/entities/user.entity';

// type SafeUser = {
//   id: string;
//   email: string;
//   name?: string;
//   role?: string;
// };

// @Injectable()
// export class AuthService {
//   private readonly logger = new Logger(AuthService.name);

//   private readonly JWT_SECRET: string;
//   private readonly JWT_ISSUER?: string;
//   private readonly JWT_AUDIENCE?: string;

//   constructor(
//     private readonly users: UsersService,
//     private readonly jwt: JwtService,
//     private readonly cfg: ConfigService,

//     @InjectRepository(User)
//     private readonly usersRepo: Repository<User>,
//   ) {
//     const issuer = String(this.cfg.get('JWT_ISSUER') ?? '').trim();
//     const audience = String(this.cfg.get('JWT_AUDIENCE') ?? '').trim();

//     this.JWT_SECRET = String(this.cfg.get('JWT_SECRET') ?? '').trim();
//     this.JWT_ISSUER = issuer || undefined;
//     this.JWT_AUDIENCE = audience || undefined;

//     if (!this.JWT_SECRET) {
//       throw new Error('JWT_SECRET is missing (check your .env)');
//     }
//   }

//   /** 회원가입 + access/refresh 토큰 발급 */
//   async register(dto: RegisterDto) {
//     const exists = await this.users.findByEmail?.(dto.email);
//     if (exists) throw new ConflictException('EMAIL_IN_USE');

//     const newUser = await this.users.create(dto);

//     const safe = this.toSafeUser(newUser);
//     const accessToken = await this.signAccessToken(safe);
//     const refreshToken = await this.signRefreshToken(safe);

//     this.logger.log(`회원가입 완료: ${newUser.email}`);

//     return {
//       accessToken,
//       refreshToken,
//       user: safe,
//     };
//   }

//   /** 로그인 + access/refresh 토큰 발급 */
//   async login(dto: LoginDto) {
//     this.logger.log(`로그인 시도: ${dto.email}`);

//     // passwordHash는 엔터티에서 select:false → 로그인 때만 addSelect로 포함
//     const user = await this.usersRepo
//       .createQueryBuilder('user')
//       .addSelect('user.passwordHash') // ← 엔터티 프로퍼티명 기준
//       .where('user.email = :email', { email: dto.email })
//       .andWhere('user.deletedAt IS NULL') // ← 엔터티 프로퍼티명 기준
//       .getOne();

//     if (!user) {
//       this.logger.warn(`유저 없음: ${dto.email}`);
//       throw new UnauthorizedException('Invalid credentials');
//     }

//     const ok = await bcrypt.compare(dto.password, user.passwordHash);
//     if (!ok) {
//       this.logger.warn(`비밀번호 불일치: ${dto.email}`);
//       throw new UnauthorizedException('Invalid credentials');
//     }

//     const safe = this.toSafeUser(user);
//     const accessToken = await this.signAccessToken(safe);
//     const refreshToken = await this.signRefreshToken(safe);

//     this.logger.log(`로그인 성공: ${dto.email}`);

//     return {
//       accessToken,
//       refreshToken,
//       user: safe,
//     };
//   }

//   /** 리프레시 토큰으로 액세스 토큰 재발급 (stateless) */
//   async refresh(refreshToken: string) {
//     if (!refreshToken) throw new UnauthorizedException('NO_REFRESH_TOKEN');

//     const verifyOpts: any = {
//       secret: this.JWT_SECRET,
//       issuer: this.JWT_ISSUER,
//       audience: this.JWT_AUDIENCE,
//     };

//     let payload: any;
//     try {
//       payload = await this.jwt.verifyAsync(refreshToken, verifyOpts);
//     } catch {
//       throw new UnauthorizedException('INVALID_REFRESH');
//     }

//     if (payload?.type !== 'refresh' || !payload?.sub) {
//       throw new UnauthorizedException('INVALID_REFRESH');
//     }

//     // UsersService 시그니처 유연 대응
//     let user: any = null;
//     if ((this.users as any).findOne) {
//       user = await (this.users as any).findOne(payload.sub);
//     }
//     if (!user && (this.users as any).findOneByUuid) {
//       user = await (this.users as any).findOneByUuid(payload.sub as string);
//     }
//     if (!user && payload.email && (this.users as any).findByEmail) {
//       user = await (this.users as any).findByEmail(payload.email);
//     }

//     if (!user) throw new UnauthorizedException('USER_NOT_FOUND');

//     const safe = this.toSafeUser(user);
//     const accessToken = await this.signAccessToken(safe);
//     return accessToken; // 컨트롤러에서 { ok:true, data:{ accessToken } } 형태로 감싸서 응답
//   }

//   // ───────── helpers ─────────
//   private toSafeUser(u: any): SafeUser {
//     return {
//       id: String(u.id), // number → string 캐스팅으로 JWT sub 일관성
//       email: u.email,
//       name: u.name,
//       role: (u.role as string) ?? 'USER',
//     };
//   }

//   private async signAccessToken(user: SafeUser) {
//     const expiresIn = this.cfg.get<string>('JWT_EXPIRES') ?? '15m';
//     const payload = {
//       sub: user.id,
//       email: user.email,
//       name: user.name,
//       role: user.role ?? 'USER',
//       type: 'access',
//     };

//     return this.jwt.signAsync(payload, {
//       secret: this.JWT_SECRET,
//       expiresIn,
//       issuer: this.JWT_ISSUER,
//       audience: this.JWT_AUDIENCE,
//     });
//   }

//   private async signRefreshToken(user: SafeUser) {
//     const expiresIn = this.cfg.get<string>('REFRESH_EXPIRES') ?? '7d';
//     const payload = { sub: user.id, type: 'refresh' };

//     return this.jwt.signAsync(payload, {
//       secret: this.JWT_SECRET,
//       expiresIn,
//       issuer: this.JWT_ISSUER,
//       audience: this.JWT_AUDIENCE,
//     });
//   }
// }
