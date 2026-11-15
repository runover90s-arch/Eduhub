# Quy tắc giám sát G2 – EduHub

## Quy định tính điểm

- Mỗi sự cố đủ điều kiện và đã ghi nhật ký: **trừ 1,0 điểm trên thang 10**.
- Điểm cuối = `max(0, điểm học thuật - số sự cố chưa được miễn trừ)`.
- Những sự kiện xảy ra cách nhau dưới **1.800 ms** được xem như cùng một đợt chuyển trạng thái trong bản monitor phía máy; chỉ phát một sự cố. Server loại trùng `event_key` theo phiên thi.
- Dạng ghi nhận: `app_background`, `screen_off`, `multi_window`, `focus_lost` (loại cuối có trong schema/API; thiết bị không bảo đảm phát hiện mọi lần).
- Trong bản trực tuyến, admin có thể miễn trừ kèm lý do và server sẽ tính lại `penalty_count` và `final_score`.

## Các giới hạn công bằng & kỹ thuật

- Đây là **quan sát lifecycle**, không phải chứng cứ gian lận. Học viên cần thấy quy tắc trước khi thi và được quyền phúc tra.
- Cuộc gọi đến, bị hệ điều hành dừng, đổi mạng, sự cố pin có thể phát sinh cảnh báo. Không đánh đồng với cố ý gian lận.
- Android có đa cửa sổ, ứng dụng hệ thống và hành vi quản lý tiến trình khác nhau. Không thể cam kết phát hiện tất cả lần chuyển ứng dụng.
- Nếu hệ thống kết thúc tiến trình trước khi client đồng bộ, có thể mất nhật ký chưa gửi. Thời gian làm bài vẫn được máy chủ tính từ lúc bắt đầu phiên khi online.
- `FLAG_SECURE` giúp hạn chế chụp/quay màn hình trên các bản Android tuân thủ API, không bảo vệ tuyệt đối nội dung.
- Không thu âm, chụp ảnh camera, đọc ứng dụng khác, hoặc yêu cầu Accessibility Service.

## Thiết kế server

`eh_start_attempt`: tạo phiên thi gắn user. `eh_save_draft`: chỉ chấp nhận bản nháp trước hạn. `eh_log_incident`: đối chiếu phiên đang hoạt động và xác nhận ownership. `eh_submit_attempt`: chấm theo khóa đáp án riêng; điểm G2 lấy từ log server. `eh_waive_incident`: chỉ admin và có lý do.

Bản demo không có server: G2 demo chỉ minh họa; không nên coi điểm demo là kết quả giám sát chính thức.

**Cần kiểm thử trực tiếp trên nhiều máy Android (tắt màn hình, đa nhiệm, cuộc gọi, mất mạng, kill process) trước khi áp dụng G2 cho bài thi có hậu quả học tập thực tế.**
