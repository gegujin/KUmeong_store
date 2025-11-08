// src/modules/products/upload.util.ts
import { diskStorage } from 'multer';
import * as fs from 'fs';
import * as path from 'path';

const uploadDir = path.join(process.cwd(), 'uploads');

// 앱 시작 시 폴더 보장
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// "이름 없는 확장자"(.jpg) 또는 빈 이름 방어 + 허용문자만
function buildSafeFilename(originalname?: string): string {
  const raw = originalname ?? '';
  const parsed = path.parse(raw);
  const ext = parsed.ext && parsed.ext.length <= 10 ? parsed.ext : '.jpg'; // 과도한 확장자 방지
  let name = (parsed.name || '').replace(/\s+/g, '_').replace(/[^a-zA-Z0-9._-]/g, '');
  if (!name || name === '.' || name === '..') name = 'image';
  return `${Date.now()}-${name}${ext}`.slice(0, 200);
}

export const productImageStorage = diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => cb(null, buildSafeFilename(file.originalname)),
});
