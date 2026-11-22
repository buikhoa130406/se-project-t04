# Từ điển dữ liệu (`data-dictionary.md` — Task 3.1.2)

- **Nguồn DDL:** `docs/design/data/schema.sql` (PostgreSQL 16)
- **Quy ước:** Mọi khóa chính/khóa ngoại nội bộ trong DB dùng kiểu `bigint` (số nguyên 64-bit). Trên JSON/URL của hợp đồng API `#34` (đã cập nhật commit `fe55c40`), các khóa ID được truyền dưới dạng chuỗi số nguyên (`string`, ví dụ `"courtId": "1"`, `"expectedBookingIds": ["201"]`) và được chuyển đổi tương ứng với `bigint` trong DB. Thời gian lưu ở dạng `timestamptz` (UTC). Vai trò chủ sân thống nhất `FACILITY_OWNER`. Thông báo đồng bộ `isRead`, `unreadOnly`, `unreadCount`, `PATCH /notifications/:notificationId/read` với `notification.is_read`.

---

## `DB-TBL-01`..`DB-TBL-12`: Danh sách 12 bảng trong `schema.sql`
1. `app_user` (`id` PK, `email` UQ, `phone` UQ, `role` `PLAYER` | `FACILITY_OWNER`)
2. `sport` (`id` PK, `name` UQ)
3. `amenity` (`id` PK, `name` UQ)
4. `facility` (`id` PK, `owner_id` FK, `sport_id` FK, `district`)
5. `facility_amenity` (`facility_id`, `amenity_id` PK)
6. `operating_hours` (`facility_id`, `day_of_week` PK, `open_time`, `close_time`)
7. `court` (`id` PK, `facility_id` FK, `status` `ACTIVE` | `DELETED`, `deleted_at`)
8. `court_price` (`court_id`, `effective_from` PK, `amount_per_slot`)
9. `hold` (`id` PK, `user_id` FK, `facility_id` FK, `source` `APP` | `IN_PERSON`, `status`, `expires_at`, `released_at`, `release_failed_at`)
10. `booking` (`id` PK, `hold_id` UQ/FK, `user_id` FK, `facility_id` FK, `source` FK, `status`, `cancelled_at`, `cancel_reason`, `cancel_note`)
11. `schedule_entry` (`id` PK, `court_id`, `facility_id`, `start_time`, `end_time`, `entry_type`, `hold_id`, `booking_id`, `blocked_by`, `unit_price`, `is_active`, `EXCLUDE` chống trùng)
12. `notification` (`id` PK, `user_id` FK, `booking_id` FK, `reason`, `message`, `is_read`, `affected_items` jsonb)
