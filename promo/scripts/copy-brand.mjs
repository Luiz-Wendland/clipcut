import { copyFile, mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const publicDir = resolve(import.meta.dirname, '../public');
await mkdir(publicDir, {recursive: true});
await copyFile(
  resolve(root, 'assets/branding/clipcut-split-timeline-smooth.svg'),
  resolve(publicDir, 'clipcut-brand.svg'),
);
