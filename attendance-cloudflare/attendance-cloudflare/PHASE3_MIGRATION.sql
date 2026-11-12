-- V4 Phase 3: Phiên điểm danh. Chạy sau khi đã tạo class_students và class_schedules.
CREATE TABLE IF NOT EXISTS attendance_sessions (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 schedule_id INTEGER NOT NULL REFERENCES class_schedules(id) ON DELETE RESTRICT,
 class_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE RESTRICT,
 starts_at TEXT NOT NULL,
 ends_at TEXT NOT NULL,
 closed_at TEXT,
 mode TEXT NOT NULL DEFAULT 'scheduled' CHECK(mode IN ('scheduled','demo')),
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CHECK (ends_at > starts_at)
);
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_time ON attendance_sessions(starts_at,ends_at);
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_class ON attendance_sessions(class_id,starts_at);
CREATE TABLE IF NOT EXISTS session_attendance (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 session_id INTEGER NOT NULL REFERENCES attendance_sessions(id) ON DELETE RESTRICT,
 student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
 checked_at TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('on_time','late')),
 latitude REAL NOT NULL,
 longitude REAL NOT NULL,
 distance REAL NOT NULL,
 face_similarity REAL NOT NULL,
 UNIQUE(session_id,student_id)
);
CREATE INDEX IF NOT EXISTS idx_session_attendance_student ON session_attendance(student_id,session_id);
