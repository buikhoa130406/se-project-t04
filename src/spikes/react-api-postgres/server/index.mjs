import express from 'express';
import { pool } from './db.mjs';

const app = express();
const host = '127.0.0.1';
const port = 3001;
const route = '/api/courts/1/price';
const maxPrice = 2_147_483_647;

app.use(express.json({ limit: '4kb' }));

pool.on('error', (error) => {
  console.error('Kết nối PostgreSQL:', error.message);
});

function sendCourt(response, court) {
  response.set('Cache-Control', 'no-store');
  if (!court) {
    return response.status(404).json({ error: 'Chưa có sân mẫu. Hãy chạy npm run db:init.' });
  }
  return response.json(court);
}

app.get(route, async (_request, response) => {
  const result = await pool.query(
    'SELECT id, name, price_vnd AS "priceVnd" FROM courtconnect_spike_court WHERE id = 1',
  );
  sendCourt(response, result.rows[0]);
});

app.put(route, async (request, response) => {
  const priceVnd = request.body?.priceVnd;
  if (!Number.isInteger(priceVnd) || priceVnd < 0 || priceVnd > maxPrice) {
    return response.status(400).json({ error: 'Nhập giá nguyên từ 0 đến 2.147.483.647 đồng.' });
  }

  const result = await pool.query(
    'UPDATE courtconnect_spike_court SET price_vnd = $1 WHERE id = 1 RETURNING id, name, price_vnd AS "priceVnd"',
    [priceVnd],
  );
  sendCourt(response, result.rows[0]);
});

app.use((error, _request, response, _next) => {
  if (error.type === 'entity.parse.failed') {
    return response.status(400).json({ error: 'Dữ liệu gửi lên phải là JSON hợp lệ.' });
  }
  if (error.type === 'entity.too.large') {
    return response.status(413).json({ error: 'Dữ liệu gửi lên vượt kích thước cho phép.' });
  }

  console.error('Yêu cầu PostgreSQL thất bại:', error.message);
  return response.status(503).json({
    error: 'API chưa đọc hoặc ghi được PostgreSQL. Kiểm tra cấu hình .env và chạy npm run db:init.',
  });
});

app.listen(port, host, (error) => {
  if (error) {
    console.error('Khởi động API thất bại:', error.message);
    process.exitCode = 1;
    return;
  }
  console.log('API: http://' + host + ':' + port + route);
});
