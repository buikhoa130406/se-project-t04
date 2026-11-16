import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

const api = '/api/courts/1/price';
const currency = new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' });

async function requestCourt(options) {
  const response = await fetch(api, options);
  const body = await response.json().catch(() => null);
  if (!response.ok || !body) {
    throw new Error(body?.error || 'Không nhận được phản hồi từ API. Kiểm tra terminal chạy Express.');
  }
  return body;
}

function App() {
  const [court, setCourt] = useState(null);
  const [price, setPrice] = useState('');
  const [pending, setPending] = useState(true);
  const [notice, setNotice] = useState('Đang đọc giá từ PostgreSQL…');
  const [error, setError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    requestCourt({ signal: controller.signal })
      .then((record) => {
        setCourt(record);
        setPrice(String(record.priceVnd));
        setNotice('Đã đọc giá từ PostgreSQL.');
      })
      .catch((failure) => {
        if (!controller.signal.aborted) setError(failure.message);
      })
      .finally(() => {
        if (!controller.signal.aborted) setPending(false);
      });
    return () => controller.abort();
  }, []);

  async function savePrice(event) {
    event.preventDefault();
    setPending(true);
    setError('');
    setNotice('Đang lưu giá…');

    try {
      const record = await requestCourt({
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ priceVnd: Number(price) }),
      });
      setCourt(record);
      setPrice(String(record.priceVnd));
      setNotice('Đã lưu vào PostgreSQL. Tải lại trang để kiểm tra.');
    } catch (failure) {
      setError(failure.message);
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="panel">
      <p className="project">CourtConnect</p>
      <h1>Thử nghiệm giá sân</h1>
      <p className="summary">React đọc và cập nhật giá sân qua Express và PostgreSQL.</p>

      <div className="court" aria-live="polite">
        <span>Giá hiện tại · {court?.name || 'Sân mẫu'}</span>
        <strong>{court ? currency.format(court.priceVnd) : '—'}</strong>
      </div>

      <form onSubmit={savePrice}>
        <label htmlFor="price">Giá mới (VND)</label>
        <div className="controls">
          <input
            id="price"
            type="number"
            min="0"
            step="1"
            value={price}
            onChange={(event) => setPrice(event.target.value)}
            required
            disabled={!court || pending}
          />
          <button type="submit" disabled={!court || pending}>Lưu giá</button>
        </div>
      </form>

      {error ? <p className="error" role="alert">{error}</p> : <p role="status">{notice}</p>}
    </main>
  );
}

createRoot(document.getElementById('root')).render(<App />);
