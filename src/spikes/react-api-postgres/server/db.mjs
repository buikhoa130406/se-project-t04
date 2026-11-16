import pg from 'pg';

for (const name of ['PGHOST', 'PGDATABASE', 'PGUSER']) {
  if (!process.env[name]?.trim()) {
    throw new Error('Thiếu ' + name + '. Tạo .env từ .env.example và điền cấu hình PostgreSQL thử nghiệm.');
  }
}

export const pool = new pg.Pool({ connectionTimeoutMillis: 3000 });
