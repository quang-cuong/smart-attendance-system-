# Smart Attendance Admin V2

Bản này nâng cấp giao diện quản trị:
- Dashboard tổng quan
- Quản lý sinh viên: thêm, sửa, xóa, tìm kiếm
- Đăng ký khuôn mặt bằng camera trình duyệt
- Hiển thị trạng thái sinh viên đã có/chưa có dữ liệu khuôn mặt
- Quản lý lớp: thêm, sửa, xóa
- Nhập vĩ độ, kinh độ, bán kính
- Nút lấy vị trí GPS hiện tại
- Lịch sử điểm danh và GPS
- Giữ giao diện Cloudflare Worker + D1 của bản V1

## API hiện đang dùng

https://attendance-cloudflare.quangcuongdk1.workers.dev

GET:
- /api/health
- /api/students
- /api/classes
- /api/attendance

POST hiện có:
- /api/students

## API cần bổ sung trong Cloudflare Worker

Để các nút Sửa/Xóa/Thêm lớp và lưu khuôn mặt hoạt động thật với D1, Worker cần hỗ trợ:

### Sinh viên
PUT /api/students/:id
Body:
{"full_name":"Nguyễn Văn A"}

DELETE /api/students/:id

### Khuôn mặt
POST /api/students/:id/face
Body:
{"image_base64":"data:image/jpeg;base64,..."}

Endpoint này phải xử lý ảnh/embedding theo kiến trúc nhận diện khuôn mặt của hệ thống. Giao diện không tự giả định rằng ảnh JPEG đã là embedding 192 chiều.

### Lớp
POST /api/classes
Body:
{"class_code":"CLASS01","class_name":"Lớp học","latitude":16.032114,"longitude":108.221900,"radius":100}

PUT /api/classes/:id
Body:
{"class_name":"Lớp học","latitude":16.032114,"longitude":108.221900,"radius":100}

DELETE /api/classes/:id

## Lưu ý quan trọng về khuôn mặt

Trang web có thể mở camera và chụp ảnh. Việc lưu embedding 192 chiều vào D1 vẫn phải do API/Worker hoặc một dịch vụ nhận diện xử lý. Vì ZIP này chỉ chứa frontend admin, không có mã Cloudflare Worker nên chưa thể tự ý đoán schema và logic lưu face_data.

## Chạy

Nếu máy có Python:
python -m http.server 5500

Sau đó mở:
http://localhost:5500/admin.html

Có thể dùng VS Code Live Server thay cho Python.

## GPS

Khi bấm "Lấy vị trí hiện tại", trình duyệt sẽ xin quyền vị trí. Tọa độ lấy được sẽ điền vào form lớp. Khi bấm "Lưu lớp", frontend gửi latitude, longitude và radius cho API.

## Cần gửi thêm Worker

Nếu muốn tôi làm phần database chạy thật 100%, hãy gửi thêm file Cloudflare Worker (ví dụ worker.js, index.js hoặc thư mục src của Worker). Tôi sẽ nối chính xác các API PUT/DELETE/POST vào bảng D1 hiện tại, tránh làm sai schema.
