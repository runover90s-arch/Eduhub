# EduHub 2.0 — ứng dụng Flutter cho học tập và kiểm tra

**Trạng thái: nguồn Flutter beta để kiểm thử và triển khai, không phải APK đã được build.**

Đây là dự án Flutter **viết mới**, không còn dùng Android WebView / HTML / JavaScript làm giao diện. Dự án hướng tới Android trước tiên, có cơ chế dữ liệu mẫu và cấu hình tùy chọn để sử dụng Supabase cho tài khoản thực.

## Phạm vi sản phẩm

- Giao diện tiếng Việt: Trang chủ, Đánh giá, Bài làm, Gói mua, Cá nhân.
- Đăng ký, đăng nhập, khôi phục mật khẩu; phân vai học viên, giáo viên, admin bằng `auth.users.raw_app_meta_data` (chỉ hệ thống được chỉnh sửa).
- Đề thi, bài học; gắn môn/lớp, mức độ, quyền miễn phí/PRO; công bố nội dung bằng EduHub Studio.
- 6 dạng câu: chọn một, chọn nhiều, đúng/sai theo từng ý, trả lời ngắn, nối cặp, tự luận chờ chấm.
- Công thức LaTeX native bằng `flutter_math_fork`; hình minh họa HTTPS; lưu nháp, đếm giờ, xem đáp án, lời giải, lịch sử.
- G2: ghi nhận sự kiện mất hiển thị khi thi, tắt màn hình, đa nhiệm; với mỗi sự cố được lưu, trừ 1 điểm trên thang 10. Có nhật ký, tránh ghi trùng trong 1,8 giây và quản trị phúc tra.
- Lớp học, mã tham gia, giao đề, thống kê giáo viên, thông báo trong ứng dụng, bảng xếp hạng tùy chọn, ghi chú và hoàn thành bài học.
- **Chỉ giữ lại danh mục gói/Combo và yêu cầu cấp quyền**; tài khoản quản trị có thể duyệt cấp quyền theo quy trình thủ công.
- Không có AI phân tích, cộng tác viên, hoa hồng, ví điện tử, hoặc nghiệp vụ thương mại mở rộng.

**Thanh toán qua mã QR/chuyển khoản, đối soát thanh toán, thông báo push khi ứng dụng đóng, trích xuất tự động PDF/Word và quét QR bằng camera: chưa làm trong bản này**. Không có dòng tiền tự động hoặc thông báo giả về thanh toán thành công.

## Tạo APK bằng GitHub Actions

1. Tạo repository **riêng tư** mới trên GitHub nếu đang phát triển và đưa toàn bộ file trong thư mục này vào root repo, bao gồm `.github/workflows/build-apk.yml`.
2. Tạo branch `main` và push source. Mở tab **Actions → EduHub Flutter - Build Android APK → Run workflow** (hoặc workflow chạy tự động khi push).
3. Workflow cố định **Flutter 3.47.9** và tự tạo khung thư mục Android bằng `flutter create`, cài native G2, chạy `flutter analyze`, `flutter test`, test Python rồi build `app-debug.apk`.
4. Nếu mọi bước thành công, mở run và tải artifact `EduHub-Flutter-Debug-APK` → tệp `app-debug.apk`.
5. Đây là **debug APK**, chưa có ký số release/Google Play và chưa được xác nhận chạy trên máy thật. G2 cần được kiểm thử trên thiết bị thực trước khi áp dụng điểm phạt.

Nếu workflow thất bại, **không có APK hợp lệ**. Mở bước đỏ và đối chiếu mã lỗi; không bỏ qua `flutter analyze` hoặc `flutter test`.

### Test trực tiếp khi có Flutter SDK

```bash
flutter create --platforms=android --org vn.eduhub --project-name eduhub .
python3 scripts/patch_android.py
flutter pub get
flutter analyze
flutter test
python3 -m unittest discover -s scripts -p 'test_*.py' -v
flutter build apk --debug
```

Phiên bản SDK và dependency ở `pubspec.yaml` cố định trực tiếp để tránh tự động nâng cấp major. Do môi trường viết source này không cài được Flutter SDK, chưa tạo được `pubspec.lock`. Sau lượt `flutter pub get` thành công đầu tiên, **hãy commit `pubspec.lock` lên repository** để khóa cả dependency gián tiếp; đừng commit SDK keys/secret keys.

## Chạy demo ngoại tuyến

Nếu chưa cấu hình Supabase, app dùng `assets/data/demo.json` làm bộ đề và bài học mô phỏng. Ứng dụng lưu câu trả lời/ghi chú/lịch sử cơ bản trên thiết bị. **Đăng nhập, phân quyền admin, đăng đề cho người dùng khác, duyệt gói và đồng bộ thiết bị không hoạt động ở demo**. Không có tài khoản admin mặc định kiểu `admin/admin`.

## Bật Supabase thật (cơ sở dữ liệu mới)

Xem [`docs/ADMIN_SETUP.md`](docs/ADMIN_SETUP.md). Chạy SQL theo đúng thứ tự **`backend/01_schema.sql` → `backend/02_functions.sql` → `backend/03_seed_packages.sql` (tùy chọn)** trong SQL Editor của dự án Supabase mới. Không chạy các SQL này lên hệ thống EduHub cũ mà không có backup và kế hoạch migration dữ liệu.

Trong repository GitHub: **Settings → Secrets and variables → Actions**, thêm:

- `SUPABASE_URL`: URL Supabase project (ví dụ `https://project-id.supabase.co`).
- `SUPABASE_PUBLISHABLE_KEY`: **publishable key** của project (được phép nhúng vào client). Không dùng `service_role` hoặc secret key.

Workflow truyền các giá trị bằng `--dart-define`. Để build thủ công:

```bash
flutter build apk --debug \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Lưu ý: Khi đã cấu hình backend, app đọc **nội dung công bố trên Supabase** chứ không tự import bộ demo. Admin cần tạo đề/bài học trước để người dùng thấy.

## Nhập đề vào EduHub Studio

Admin có thể nhập từng câu hoặc **nhập nguyên đề JSON**. Bộ nhập kiểm tra đáp án, xem trước LaTeX, sau đó **chỉ tạo bản nháp**. Bản nháp không tự công bố; admin rà soát và bấm *Công bố*.

Xem [`docs/IMPORT_FORMAT.md`](docs/IMPORT_FORMAT.md) và [`docs/LATEX.md`](docs/LATEX.md). Có thể đính kèm liên kết ảnh HTTPS để minh họa biểu đồ và hình vẽ. Chưa hỗ trợ upload ảnh vào Supabase Storage trực tiếp từ app.

## Thư mục chính

```text
lib/main.dart                  Điều hướng Flutter, Supabase bootstrap
lib/core/                    Theme, cài đặt, quan sát G2
lib/data/                    Model, chấm điểm demo, repository, nhập đề
lib/features/                Trang chủ, kho đề, phòng thi, học, gói, tài khoản, Studio
lib/widgets/rich_math.dart   Bộ hiển thị LaTeX trực tiếp trong Flutter
native/MainActivity.kt       Cầu nối Android giám sát G2
backend/                     SQL bảng, RLS, RPC, gói mẫu
assets/data/demo.json        Đề và bài học mô phỏng tự biên soạn
.github/workflows/           Kiểm thử và tạo debug APK
scripts/                     Patching và kiểm tra cấu trúc
```

## Trạng thái kiểm thử

Có **8 kiểm thử source-level Python đã chạy và đạt** trong môi trường hiện tại. Các unit/widget test Dart nằm trong `test/` và được GitHub Actions cấu hình để thực thi, nhưng **chưa chạy ở môi trường này** do không có Flutter/Dart SDK. Chưa chạy SQL thực, kiểm tra RLS thực tế hoặc build/install APK. Xem [`docs/TEST_REPORT.md`](docs/TEST_REPORT.md) và [`docs/IMPLEMENTATION_STATUS.md`](docs/IMPLEMENTATION_STATUS.md).

## Bảo vệ dữ liệu và đánh giá G2

- Khóa đáp án chỉ ở bảng `eh_answer_keys` RLS cho admin. Không gửi khóa đáp án trong API đọc đề khi thi; chấm server ở RPC `eh_submit_attempt`.
- Mỗi phiên thi trực tuyến dùng thời gian máy chủ và lưu nháp. Sau hạn, chỉ phần nháp đã đồng bộ trước thời hạn mới được chấm.
- Khả năng phát hiện chuyển ứng dụng/tắt màn hình là **best-effort**: không thể khẳng định phát hiện tất cả trường hợp hoặc chống được thiết bị đã sửa đổi. Người học có thể yêu cầu phúc tra khi cuộc gọi đến, sự cố hệ thống hoặc báo nhầm.
- Điểm G2 học thuật là *điểm trước phạt*, điểm cuối tối thiểu 0. Không ghi âm, chụp ảnh lén hoặc theo dõi ứng dụng khác.
- Ứng dụng có thể không gửi kịp sự cố khi tiến trình bị hệ điều hành dừng; server chưa có cơ chế anti-tamper mức thi quốc gia.

Xem chi tiết [`docs/G2_POLICY.md`](docs/G2_POLICY.md).
