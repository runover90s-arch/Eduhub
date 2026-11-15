# Báo cáo kiểm thử EduHub Flutter 2.0

## Đã chạy tại môi trường xây dựng source

- `python3 -m unittest discover -s scripts -p 'test_*.py' -v`: **8/8 passed**.
- Kiểm tra dữ liệu demo JSON gồm nhiều đề, đủ sáu dạng câu và thứ tự hợp lệ: đạt.
- Quét source Flutter/SQL để loại bỏ AI affiliate/commission/payment webhook: đạt.
- Kiểm tra sự hiện diện lớp chấm, RLS đáp án, code native Android G2, LaTeX, GitHub workflow: đạt.
- Kiểm tra cấu trúc ngoặc Dart theo bộ scanner nhẹ: đạt (không thay cho Dart analyzer).
- Kiểm tra nguồn nhập JSON không tự công bố và thiết lập cỡ chữ được lưu: đạt.

## Có trong repository nhưng **CHƯA CHẠY** tại môi trường này

- `flutter analyze`: chưa chạy vì không có Flutter SDK/Dart SDK.
- `flutter test`: chưa chạy (unit grade, parser LaTeX, import JSON và widget test).
- `flutter build apk --debug`: chưa chạy; chưa có tệp APK được tạo.
- Các file SQL/RLS: chưa thực thi trên Supabase project thật.
- G2 trên thiết bị Android: chưa test màn hình tắt/multiwindow/cuộc gọi/kill process.
- Luồng mua gói/chuyển quyền, lớp giáo viên và thống kê: chưa tích hợp online end-to-end.

## Cổng chất lượng GitHub Actions

Workflow chạy `flutter create → patch Android → flutter pub get → flutter analyze → flutter test → Python tests → flutter build apk`. Chỉ xuất APK nếu các bước trước thành công. Theo dõi lỗi trực tiếp trên run của GitHub Actions để xác minh.

## QA bắt buộc trước phát hành

1. Cài APK trên thiết bị Android 7–16 và kiểm tra điều hướng, overflow, font/LaTeX, ảnh minh họa, xoay màn hình.
2. Tạo 3 tài khoản trong Supabase test (học viên/giáo viên/admin), kiểm tra truy vấn ngoài quyền bị từ chối, đáp án không lộ trước nộp.
3. Test khóa PRO, hiệu lực quyền, thay gói/combo, danh sách được công bố, đề bản nháp và đề đã lưu trữ.
4. Test G2 lặp đi lặp lại (call, screen lock, app switch, multi-window, không mạng, ứng dụng bị kill), kiểm tra incident trùng, phúc tra và điểm cuối.
5. Test lúc hết giờ; đảm bảo server chỉ chấm dữ liệu đã đồng bộ đúng hạn, không tin giờ của client.
6. Kiểm thử độ đọc LaTeX/đồ thị với bộ đề thật, chạy `flutter analyze`, `flutter test`, `flutter build apk` và kiểm tra artifact.
