// src/core/config/config.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { EnvSchema } from './env.schema';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: (config) => {
        const parsed = EnvSchema.safeParse(config);
        if (!parsed.success) {
          console.error(parsed.error.format());
          throw new Error('Invalid ENV');
        }
        return parsed.data;
      },
    }),
  ],
})
export class AppConfigModule {}
