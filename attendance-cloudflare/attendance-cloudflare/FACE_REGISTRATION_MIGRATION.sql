-- Giai đoạn 3B: đăng ký Face ID theo tài khoản, chờ Admin duyệt.
-- Không xóa bảng face_data hiện có.
CREATE TABLE IF NOT EXISTS face_registration_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  embedding TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_face_registration_status ON face_registration_requests(status,created_at);
