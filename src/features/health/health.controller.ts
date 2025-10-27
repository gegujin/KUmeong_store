// src/features/health/health.controller.ts
import { Controller, Get, Version } from '@nestjs/common';
@Controller('health')
export class HealthController {
  @Version('1')
  @Get()
  get() {
    return { ok: true, status: 'up', ts: new Date().toISOString() };
  }
}
