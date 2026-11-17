import { readFile } from 'node:fs/promises';
import { pool } from '../server/db.mjs';

try {
  const sql = await readFile(new URL('../db/seed.sql', import.meta.url), 'utf8');
  await pool.query(sql);
  console.log('Sân mẫu đã sẵn sàng trong PostgreSQL. Giá đã lưu được giữ khi chạy lại.');
} catch (error) {
  console.error('Khởi tạo dữ liệu mẫu thất bại:', error.message);
  process.exitCode = 1;
} finally {
  await pool.end();
}
