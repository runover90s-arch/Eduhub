# Kết nối cơ sở dữ liệu và tài khoản quản trị EduHub

## Thiết lập cơ bản

1. Tạo một dự án Supabase MỚI, trong **Authentication → Providers → Email** bật Email Auth; cấu hình Email Confirmation và SMTP theo nhu cầu trước khi phát hành.
2. Mở SQL Editor và chạy lần lượt `backend/01_schema.sql`, `backend/02_functions.sql`. Nếu muốn ba gói mẫu, chạy thêm `backend/03_seed_packages.sql`.
3. Cấu hình `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` trong **GitHub → Repository Settings → Secrets and variables → Actions**. Không đưa secret/service role key vào app.
4. Build debug APK bằng Actions. Đăng ký tài khoản thật qua EduHub, xác nhận email theo cấu hình project.
5. Mở Supabase Dashboard → Authentication → Users, tìm UID tài khoản của bạn. Trong môi trường Dashboard SQL Editor (quyền admin DB), thay UUID dưới đây và thực hiện **một lần**:

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data,'{}'::jsonb) || '{"role":"admin"}'::jsonb
where id = 'YOUR-OWN-USER-UUID'::uuid;
```

Sau đó đăng xuất/đăng nhập lại để refresh JWT. Role `admin` không được set qua `raw_user_meta_data` vì người dùng có thể tự sửa metadata đó. Để cấp quyền giáo viên, dùng role `teacher` tương tự với UID của giáo viên.

**Không có thông tin đăng nhập quản trị cài sẵn.** Không đưa mật khẩu thật vào `README`, GitHub Actions log, hay tệp source.

## Quy trình công bố đề

- Admin vào **Cá nhân → EduHub Studio** → tạo đề hoặc nhập đề JSON → thêm câu & khóa đáp án → rà công thức/ảnh → chuyển trạng thái `published`.
- Học viên đăng nhập nhìn thấy đề đã công bố ở Đánh giá. Khóa đáp án trong bảng `eh_answer_keys` không có policy đọc cho user thường.
- Khi cần chỉnh câu, đưa đề về bản nháp trước. Bản lưu trữ không mở cho lượt thi mới, nhưng kết quả cũ có snapshot để xem lại.
- Với quyền PRO, admin tạo package/combo và liên kết đề/bài học phù hợp hoặc bật mở tất cả PRO. `eh_orders` tạo yêu cầu `pending`, không chứng minh học viên đã trả tiền.
- Duyệt gói **thủ công** từ Studio chỉ sau khi xác nhận quyền sử dụng theo quy trình riêng. `eh_approve_order` cấp `eh_entitlements` và gửi thông báo trong app; **không có QR hoặc chuyển khoản tự động**.

## Hạn chế giai đoạn này

- Script là **schema cho project mới**, không là migration trực tiếp cho bản WebView cũ.
- Chưa chạy migration SQL thực tế trong phiên phát triển này; cần chạy trên project test trước và kiểm tra Security Advisor / RLS bằng hai tài khoản khác quyền.
- **G2 phải được test trên Android thật** trước khi áp dụng. User access và publish có thể cần tinh chỉnh theo chính sách nhà trường.
