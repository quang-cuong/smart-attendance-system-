-- Smart Attendance V4 - Phase 2: class enrollment and schedules
-- Additive migration; preserves existing tables and attendance data.
CREATE TABLE IF NOT EXISTS class_students (
    class_id INTEGER NOT NULL,
    student_id INTEGER NOT NULL,
    enrolled_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (class_id, student_id),
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_class_students_student
ON class_students(student_id, class_id);

CREATE TABLE IF NOT EXISTS class_schedules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    class_id INTEGER NOT NULL,
    subject_name TEXT NOT NULL,
    room TEXT,
    starts_at TEXT NOT NULL,
    ends_at TEXT NOT NULL,
    attendance_duration_seconds INTEGER NOT NULL DEFAULT 180
        CHECK (attendance_duration_seconds BETWEEN 60 AND 3600),
    on_time_seconds INTEGER NOT NULL DEFAULT 60
        CHECK (on_time_seconds BETWEEN 0 AND 3599),
    status TEXT NOT NULL DEFAULT 'scheduled'
        CHECK (status IN ('scheduled', 'cancelled')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (ends_at > starts_at),
    CHECK (on_time_seconds < attendance_duration_seconds),
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_class_schedules_class_start
ON class_schedules(class_id, starts_at);

CREATE INDEX IF NOT EXISTS idx_class_schedules_start
ON class_schedules(starts_at);
