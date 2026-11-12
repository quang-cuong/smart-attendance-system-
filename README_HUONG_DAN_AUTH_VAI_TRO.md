# Smart Attendance – bản bổ sung đăng nhập và phân quyền (giai đoạn 1)

## Có gì trong bản này
- Worker: đăng ký giáo viên/phụ huynh ở trạng thái chờ duyệt; đăng nhập bằng PBKDF2-SHA256 (210.000 vòng); token HMAC-SHA256 hết hạn sau 8 giờ.
- Bootstrap tạo Admin đầu tiên, chỉ hoạt động nếu cấu hình secret và chưa có tài khoản Admin.
- Admin xem/duyệt/từ chối đăng ký; xem danh sách tài khoản; API phân công giáo viên vào lớp và liên kết phụ huynh với học sinh.
- API lịch sử theo vai trò: Admin xem toàn bộ; giáo viên chỉ xem lớp đã được gán; phụ huynh chỉ xem học sinh đã liên kết.
- `smart_attendance_admin_v2/auth.html`: trang thử đăng nhập/đăng ký/duyệt và xem lịch sử theo vai trò.
- `auth-schema.sql`: SQL idempotent cho các bảng tài khoản/liên kết. Không xóa các bảng nghiệp vụ.

## Cực kỳ quan trọng trước khi triển khai
Bản Worker cũ có các API nghiệp vụ công khai (`/api/students`, `/api/classes`, `/api/attendance`, `/api/face-data`) mà ứng dụng Flutter hiện có thể đang sử dụng. Trong giai đoạn này, các API cũ vẫn được giữ tương thích và **chưa được khóa bằng token**. Vì thế đây chưa phải là trạng thái bảo mật hoàn chỉnh cho môi trường production; không được coi trang đăng nhập mới là đã bảo vệ các API cũ. Muốn khóa đúng cách, cần cập nhật Flutter để gửi token, sau đó mới bắt buộc xác thực cho các API nghiệp vụ và cập nhật `admin.html` hiện tại dùng token. Đặc biệt không công khai dữ liệu embedding khuôn mặt/lịch sử điểm danh trước khi hoàn thành bước đó.

## Triển khai an toàn
1. Sao lưu D1 trước khi thay đổi: Cloudflare Dashboard → Workers & Pages → D1 → `attendance-db` → Export/backup nếu tùy chọn hiện có.
2. Mở Cloudflare D1 Console của `attendance-db`. Nếu bạn đã chạy SQL tạo 4 bảng `accounts`, `teacher_classes`, `parent_students`, `registration_requests` thì bỏ qua; nếu chưa, chạy `attendance-cloudflare/auth-schema.sql`.
3. Mở PowerShell trong thư mục `attendance-cloudflare`, cài dependencies nếu cần:
   ```powershell
   npm ci
   ```
4. Cấu hình secrets. Mỗi lệnh sẽ yêu cầu nhập secret; không đưa secret vào mã nguồn, file `.env`, ảnh chụp hay chat:
   ```powershell
   npx wrangler secret put JWT_SECRET
   npx wrangler secret put ADMIN_BOOTSTRAP_SECRET
   ```
   Dùng hai giá trị ngẫu nhiên khác nhau, dài tối thiểu 32 ký tự. Có thể tạo bằng PowerShell:
   ```powershell
   [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
   ```
   Chạy lệnh tạo chuỗi hai lần để có hai secret riêng; nhập lần lượt khi Wrangler hỏi.
5. Kiểm tra build trước khi deploy:
   ```powershell
   npx tsc --noEmit
   ```
6. Chỉ khi đã backup và xác nhận đúng Cloudflare account/database, mới deploy:
   ```powershell
   npx wrangler deploy
   ```
7. Mở `smart_attendance_admin_v2/auth.html` bằng web server HTTPS/local server. Không nên mở qua `file://` nếu trình duyệt chặn request. Có thể chạy `npx serve smart_attendance_admin_v2 -l 5500`, rồi mở `http://localhost:5500/auth.html`.
8. Tại “Tạo Admin đầu tiên”, nhập secret `ADMIN_BOOTSTRAP_SECRET` đã cấu hình ở bước 4 và đặt mật khẩu Admin mạnh (ít nhất 12 ký tự). Bootstrap chỉ tạo được Admin đầu tiên và không dùng lại sau khi Admin tồn tại.
9. Đăng nhập Admin; xem yêu cầu đăng ký và duyệt/từ chối. Tài khoản giáo viên/phụ huynh chỉ xem được dữ liệu sau khi Admin phân công lớp/liên kết học sinh.

## API mới
- `POST /api/admin/bootstrap` – tạo Admin đầu tiên; header `X-Bootstrap-Secret`.
- `POST /api/auth/register` – body `{ "username", "email", "password", "role": "teacher" | "parent" }`.
- `POST /api/auth/login` – body `{ "username": "username-hoặc-email", "password" }`.
- `GET /api/admin/registration-requests` – Admin bearer token.
- `POST /api/admin/registration-requests/:id/approve` hoặc `/reject` – Admin bearer token.
- `GET /api/admin/accounts` – Admin bearer token.
- `POST /api/admin/teacher-classes` – body `{ "account_id": 2, "class_id": 1 }`, Admin bearer token.
- `POST /api/admin/parent-students` – body `{ "account_id": 3, "student_id": 1 }`, Admin bearer token.
- `GET /api/role/attendance` – bearer token; dữ liệu lọc theo role và liên kết.

Các API yêu cầu bearer token nhận header `Authorization: Bearer <token>`.
