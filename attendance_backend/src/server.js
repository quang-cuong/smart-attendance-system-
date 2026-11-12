const express = require('express');
const cors = require('cors');
const { pool, testDatabase } = require('./db');

const app = express();

app.use(cors());
app.use(express.json({ limit: '5mb' }));

// =========================================================
// TẠO 4 BẢNG POSTGRESQL
// =========================================================
async function createTables() {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                student_code VARCHAR(50) UNIQUE NOT NULL,
                full_name VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        await pool.query(`
            CREATE TABLE IF NOT EXISTS classes (
                id SERIAL PRIMARY KEY,
                class_code VARCHAR(50) UNIQUE NOT NULL,
                class_name VARCHAR(255) NOT NULL,
                latitude DOUBLE PRECISION NOT NULL,
                longitude DOUBLE PRECISION NOT NULL,
                radius DOUBLE PRECISION NOT NULL
            )
        `);

        await pool.query(`
            CREATE TABLE IF NOT EXISTS face_data (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL,
                embedding TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT fk_face_user
                    FOREIGN KEY (user_id)
                    REFERENCES users(id)
                    ON DELETE CASCADE
            )
        `);

        await pool.query(`
            CREATE TABLE IF NOT EXISTS attendance (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL,
                class_id INTEGER NOT NULL,
                attendance_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                latitude DOUBLE PRECISION NOT NULL,
                longitude DOUBLE PRECISION NOT NULL,
                distance DOUBLE PRECISION NOT NULL,
                face_similarity DOUBLE PRECISION NOT NULL,
                status VARCHAR(50) NOT NULL,
                CONSTRAINT fk_attendance_user
                    FOREIGN KEY (user_id)
                    REFERENCES users(id)
                    ON DELETE CASCADE,
                CONSTRAINT fk_attendance_class
                    FOREIGN KEY (class_id)
                    REFERENCES classes(id)
                    ON DELETE CASCADE
            )
        `);

        await pool.query(`
            INSERT INTO classes (
                class_code,
                class_name,
                latitude,
                longitude,
                radius
            )
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT (class_code) DO NOTHING
        `, [
            'CLASS01',
            'Lớp học',
            16.031915,
            108.223110,
            100
        ]);

        console.log('✅ Đã kiểm tra/tạo 4 bảng PostgreSQL thành công!');
        console.log('   - users');
        console.log('   - classes');
        console.log('   - face_data');
        console.log('   - attendance');
        console.log('✅ Đã kiểm tra lớp học mặc định CLASS01');

    } catch (error) {
        console.error('❌ Lỗi tạo bảng:', error.message);
    }
}

// =========================================================
// API KIỂM TRA SERVER
// =========================================================
app.get('/', (req, res) => {
    res.json({
        message: 'Attendance Backend đang chạy!',
        database: 'PostgreSQL'
    });
});

// =========================================================
// API KIỂM TRA DATABASE
// =========================================================
app.get('/api/health', async (req, res) => {
    try {
        const result = await pool.query('SELECT NOW()');

        res.json({
            server: 'OK',
            database: 'OK',
            time: result.rows[0].now
        });

    } catch (error) {
        res.status(500).json({
            server: 'OK',
            database: 'ERROR',
            message: error.message
        });
    }
});

// =========================================================
// API LẤY DANH SÁCH SINH VIÊN
// =========================================================
app.get('/api/students', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                id,
                student_code,
                full_name,
                created_at
            FROM users
            ORDER BY id ASC
        `);

        res.json(result.rows);

    } catch (error) {
        console.error('❌ Lỗi lấy sinh viên:', error.message);

        res.status(500).json({
            message: 'Không lấy được danh sách sinh viên'
        });
    }
});

// =========================================================
// API THÊM SINH VIÊN
// =========================================================
app.post('/api/students', async (req, res) => {
    try {
        const { student_code, full_name } = req.body;

        if (!student_code || !full_name) {
            return res.status(400).json({
                message: 'Thiếu mã sinh viên hoặc họ tên'
            });
        }

        const result = await pool.query(`
            INSERT INTO users (
                student_code,
                full_name
            )
            VALUES ($1, $2)
            RETURNING *
        `, [
            student_code,
            full_name
        ]);

        res.status(201).json({
            message: 'Thêm sinh viên thành công',
            student: result.rows[0]
        });

    } catch (error) {
        console.error('❌ Lỗi thêm sinh viên:', error.message);

        if (error.code === '23505') {
            return res.status(409).json({
                message: 'Mã sinh viên đã tồn tại'
            });
        }

        res.status(500).json({
            message: 'Không thêm được sinh viên'
        });
    }
});

// =========================================================
// API LƯU DỮ LIỆU KHUÔN MẶT
// =========================================================
app.post('/api/face-data', async (req, res) => {
    try {
        const { user_id, embedding } = req.body;

        if (!user_id || !embedding) {
            return res.status(400).json({
                message: 'Thiếu user_id hoặc embedding'
            });
        }

        const userCheck = await pool.query(
            'SELECT id FROM users WHERE id = $1',
            [user_id]
        );

        if (userCheck.rows.length === 0) {
            return res.status(404).json({
                message: 'Không tìm thấy sinh viên'
            });
        }

        await pool.query(
            'DELETE FROM face_data WHERE user_id = $1',
            [user_id]
        );

        const result = await pool.query(`
            INSERT INTO face_data (
                user_id,
                embedding
            )
            VALUES ($1, $2)
            RETURNING *
        `, [
            user_id,
            embedding
        ]);

        res.status(201).json({
            message: 'Lưu khuôn mặt thành công',
            face_data: result.rows[0]
        });

    } catch (error) {
        console.error('❌ Lỗi lưu khuôn mặt:', error.message);

        res.status(500).json({
            message: 'Không lưu được dữ liệu khuôn mặt'
        });
    }
});

// =========================================================
// API LẤY SINH VIÊN + KHUÔN MẶT
// =========================================================
app.get('/api/students-with-face', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                users.id,
                users.student_code,
                users.full_name,
                users.created_at,
                face_data.embedding
            FROM users
            LEFT JOIN face_data
                ON users.id = face_data.user_id
            ORDER BY users.id ASC
        `);

        res.json(result.rows);

    } catch (error) {
        console.error('❌ Lỗi lấy dữ liệu khuôn mặt:', error.message);

        res.status(500).json({
            message: 'Không lấy được dữ liệu sinh viên và khuôn mặt'
        });
    }
});

// =========================================================
// API LẤY DANH SÁCH LỚP
// =========================================================
app.get('/api/classes', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT *
            FROM classes
            ORDER BY id ASC
        `);

        res.json(result.rows);

    } catch (error) {
        console.error('❌ Lỗi lấy lớp:', error.message);

        res.status(500).json({
            message: 'Không lấy được danh sách lớp'
        });
    }
});

// =========================================================
// API LƯU ĐIỂM DANH
// =========================================================
app.post('/api/attendance', async (req, res) => {
    try {
        const {
            user_id,
            class_id,
            latitude,
            longitude,
            distance,
            face_similarity,
            status
        } = req.body;

        if (
            !user_id ||
            !class_id ||
            latitude === undefined ||
            longitude === undefined ||
            distance === undefined ||
            face_similarity === undefined ||
            !status
        ) {
            return res.status(400).json({
                message: 'Thiếu dữ liệu điểm danh'
            });
        }

        const result = await pool.query(`
            INSERT INTO attendance (
                user_id,
                class_id,
                latitude,
                longitude,
                distance,
                face_similarity,
                status
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING *
        `, [
            user_id,
            class_id,
            latitude,
            longitude,
            distance,
            face_similarity,
            status
        ]);

        res.status(201).json({
            message: 'Điểm danh thành công',
            attendance: result.rows[0]
        });

    } catch (error) {
        console.error('❌ Lỗi lưu điểm danh:', error.message);

        res.status(500).json({
            message: 'Không lưu được điểm danh'
        });
    }
});

// =========================================================
// API LẤY LỊCH SỬ ĐIỂM DANH
// =========================================================
app.get('/api/attendance', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                attendance.id,
                users.student_code,
                users.full_name,
                classes.class_code,
                classes.class_name,
                attendance.attendance_time,
                attendance.latitude,
                attendance.longitude,
                attendance.distance,
                attendance.face_similarity,
                attendance.status
            FROM attendance
            INNER JOIN users
                ON attendance.user_id = users.id
            INNER JOIN classes
                ON attendance.class_id = classes.id
            ORDER BY attendance.attendance_time DESC
        `);

        res.json(result.rows);

    } catch (error) {
        console.error('❌ Lỗi lấy lịch sử điểm danh:', error.message);

        res.status(500).json({
            message: 'Không lấy được lịch sử điểm danh'
        });
    }
});

// =========================================================
// KHỞI ĐỘNG SERVER
// =========================================================
const PORT = process.env.PORT || 3000;

async function startServer() {
    console.log('==========================================');
    console.log('   ATTENDANCE BACKEND');
    console.log('   Node.js + Express + PostgreSQL');
    console.log('==========================================');

    await testDatabase();
    await createTables();

    app.listen(PORT, '0.0.0.0', () => {
        console.log(`🚀 Server đang chạy tại http://localhost:${PORT}`);
        console.log(`🌐 Server LAN: http://172.16.168.84:${PORT}`);
        console.log(`🔗 API sinh viên: http://172.16.168.84:${PORT}/api/students`);
        console.log(`🔗 API khuôn mặt: http://172.16.168.84:${PORT}/api/face-data`);
        console.log(`🔗 API điểm danh: http://172.16.168.84:${PORT}/api/attendance`);
    });
}

startServer();