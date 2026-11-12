-- =========================================================
-- DATABASE ĐIỂM DANH THÔNG MINH & XÁC THỰC PHÂN QUYỀN
-- Cloudflare D1 / SQLite
-- =========================================================

-- =========================================================
-- BẢNG USERS
-- Lưu thông tin sinh viên / học sinh
-- =========================================================
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_code TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- BẢNG CLASSES
-- Lưu thông tin lớp học và vị trí GPS
-- =========================================================
CREATE TABLE IF NOT EXISTS classes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_code TEXT NOT NULL UNIQUE,
    class_name TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    radius REAL NOT NULL DEFAULT 100
);

-- =========================================================
-- BẢNG FACE_DATA
-- Lưu vector đặc trưng khuôn mặt MobileFaceNet
-- Embedding 192 chiều được lưu dạng TEXT
-- =========================================================
CREATE TABLE IF NOT EXISTS face_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    embedding TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);

-- =========================================================
-- BẢNG ATTENDANCE
-- Lưu lịch sử điểm danh
-- =========================================================
CREATE TABLE IF NOT EXISTS attendance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    class_id INTEGER NOT NULL,
    attendance_time TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    distance REAL NOT NULL,
    face_similarity REAL NOT NULL,
    status TEXT NOT NULL,

    FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE CASCADE,

    FOREIGN KEY (class_id)
        REFERENCES classes(id)
        ON DELETE CASCADE
);

-- =========================================================
-- BẢNG ACCOUNTS (Tài khoản người dùng: admin, teacher, parent)
-- =========================================================
CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'teacher', 'parent')),
    is_active INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('pending','active','rejected','disabled')),
    must_change_password INTEGER NOT NULL DEFAULT 0,
    credential_version INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- BẢNG REGISTRATION_REQUESTS (Đơn đăng ký tài khoản chờ duyệt)
-- =========================================================
CREATE TABLE IF NOT EXISTS registration_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL REFERENCES accounts(id),
    requested_role TEXT NOT NULL CHECK(requested_role IN ('teacher','parent')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
    reviewed_by INTEGER REFERENCES accounts(id), reviewed_at TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- BẢNG TEACHER_CLASSES (Liên kết Giáo viên với Lớp học)
-- =========================================================
CREATE TABLE IF NOT EXISTS teacher_classes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    class_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(account_id, class_id),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE
);

-- =========================================================
-- BẢNG PARENT_STUDENTS (Liên kết Phụ huynh với Học sinh/Sinh viên)
-- =========================================================
CREATE TABLE IF NOT EXISTS parent_students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    student_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(account_id, student_id),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =========================================================
-- INDEX
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_face_data_user_id ON face_data(user_id);
CREATE INDEX IF NOT EXISTS idx_attendance_user_id ON attendance(user_id);
CREATE INDEX IF NOT EXISTS idx_attendance_class_id ON attendance(class_id);
CREATE INDEX IF NOT EXISTS idx_attendance_time ON attendance(attendance_time);
CREATE INDEX IF NOT EXISTS idx_accounts_username ON accounts(username);
CREATE INDEX IF NOT EXISTS idx_accounts_email ON accounts(email);
CREATE INDEX IF NOT EXISTS idx_registration_requests_status ON registration_requests(status);
CREATE INDEX IF NOT EXISTS idx_teacher_classes_account_id ON teacher_classes(account_id);
CREATE INDEX IF NOT EXISTS idx_parent_students_account_id ON parent_students(account_id);

-- =========================================================
-- LỚP HỌC MẶC ĐỊNH
-- =========================================================
INSERT OR IGNORE INTO classes (class_code, class_name, latitude, longitude, radius)
VALUES ('CLASS01', 'Lớp học', 16.031992, 108.222306, 100);

CREATE TABLE IF NOT EXISTS student_accounts (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
 username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, salt TEXT NOT NULL,
 status TEXT NOT NULL DEFAULT 'active', must_change_password INTEGER NOT NULL DEFAULT 1,
 credential_version INTEGER NOT NULL DEFAULT 1,
 created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
