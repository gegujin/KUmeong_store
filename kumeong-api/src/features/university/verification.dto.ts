// src/features/university/verification.dto.ts
import { z } from 'zod';
export const StartSchema = z.object({
  email: z.string().email(),
  univName: z.string().min(1),
});
export const VerifySchema = z.object({
  email: z.string().email(),
  code: z.string().min(4).max(8),
});
export type StartDto = z.infer<typeof StartSchema>;
export type VerifyDto = z.infer<typeof VerifySchema>;
