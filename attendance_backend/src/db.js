const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
});

async function testDatabase() {
    try {
        const result = await pool.query('SELECT NOW()');
        console.log('✅ Kết nối PostgreSQL thành công!');
        console.log('Thời gian server:', result.rows[0].now);
    } catch (error) {
        console.error('❌ Không kết nối được PostgreSQL:', error.message);
    }
}

module.exports = { pool, testDatabase };