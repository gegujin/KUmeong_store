// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\auth\guards\jwt-auth.guard.ts
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
