// src/core/config/env.schema.ts
import { z } from 'zod';

export const EnvSchema = z.object({
  JWT_ISSUER: z.string().min(1, 'JWT_ISSUER required'),
  JWT_SECRET: z.string().min(32, 'JWT_SECRET required'),
  // ...
});

export type EnvVars = z.infer<typeof EnvSchema>;
