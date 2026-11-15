# EduHub Flutter 2.0 — Trạng thái từng module

| Phần | Trạng thái trong source | Cần trước khi phát hành |
|---|---|---|
| Khung Android Flutter thuần | Đã viết Flutter UI, native Android bridge; không dùng WebView | GitHub Action build và cài thử APK |
| Trang chủ, 5 tab, bộ lọc đề | Đã viết | QA giao diện trên Android |
| LaTeX cho bài học / câu hỏi / lời giải | Đã viết `flutter_math_fork`, có test | Chạy Flutter widget tests với công thức thực tế |
| Hình minh họa trong đề | Đã viết `image_url` HTTPS | Lưu trữ ảnh hợp pháp, ảnh dễ đọc |
| Đăng ký/đăng nhập | Đã nối Supabase Flutter 2.x | Supabase project thật, SMTP/email confirm |
| Quyền admin/giáo viên/học viên | RLS và app_metadata JWT trong SQL | Chạy SQL, test RLS bằng nhiều tài khoản |
| Studio tạo bản nháp/công bố đề | Đã viết admin Flutter + SQL trigger | Test RPC trong Supabase thật |
| Nhập đề JSON hàng loạt | Có kiểm tra, xem trước, tạo nháp, không auto publish | Chuyển dữ liệu PDF/Word thành JSON và duyệt thủ công |
| 6 dạng câu hỏi | Đã viết UI, chấm cơ bản + tự luận chờ chấm | Test theo từng dạng và cấu trúc đề thật |
| Lưu tiến độ, lịch sử, lời giải | Có lưu cục bộ và API online | Test mạng yếu, logout/login, lưu trữ đề |
| G2 trừ 1 điểm/sự cố | Đã viết Kotlin native + RPC server, có miễn trừ | **Thiết bị Android thật**, false positive, mất mạng |
| Bài học, ghi chú, học xong | Đã viết | Test online với RLS |
| Lớp học/giao bài | Đã viết và SQL RLS/teacher overview | Test teacher/student integration |
| Bảng xếp hạng | Có backend và biểu mẫu đồng ý công khai | Chạy bằng nhiều user, kiểm tra privacy |
| Thông báo trong app | Có table/trang | Chạy backend; không có FCM push |
| Gói học/Combo | Có danh mục, liên kết nội dung, yêu cầu pending, admin duyệt quyền | Test entitlements và thời hạn online |
| Thanh toán QR/chuyển khoản | **Để lại tác vụ sau**, không tích hợp | Tích hợp & đối soát đúng quy trình trong lượt tiếp theo |
| Phân tích AI / cộng tác viên / ví | **Chủ động loại bỏ** | Không cần triển khai |
| Tùy chọn học tập | Cỡ chữ, tương phản, giảm chuyển động lưu local | QA accessibility |
| APK cài đặt | Workflow cấu hình để build `app-debug.apk` | Chờ CI chạy thành công (chưa build ở đây) |

**Không có bằng chứng để kết luận đã hoàn thiện 98–99% ứng dụng gốc.** Đây là bản Flutter beta có triển khai lõi và cần vòng tích hợp thực tế. Không chứa source/ảnh bản quyền trích xuất từ APK của bên thứ ba.
