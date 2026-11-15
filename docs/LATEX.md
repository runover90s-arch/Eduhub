# Hiển thị công thức toán trong EduHub Flutter

EduHub dùng `flutter_math_fork` (render LaTeX trong widget Flutter), không nhúng WebView để render công thức.

| Cách viết nội dung | Hiển thị mục đích |
|---|---|
| `$f(x)=x^2-3x+2$` | Công thức nội dòng |
| `$$\\int_0^1 x^2\\,dx=\\frac13$$` | Công thức độc lập |
| `$\\frac{a+b}{c}$` | Phân số |
| `$\\sqrt{x^2+1}$` | Căn bậc hai |
| `$\\lim_{x\\to+\\infty}\\frac1x=0$` | Giới hạn |
| `$\\begin{cases}2x+y=3\\\\x-y=0\\end{cases}$` | Hệ phương trình (cần thử trình phân tích LaTeX hỗ trợ) |

Trong trường soạn văn bản của app, gõ lệnh LaTeX với **một** dấu backslash (`\\frac`). Trong JSON, cần escape thành **hai** backslash (`\\\\frac`).

Ngoài `$...$`, ứng dụng nhận `\\(...\\)` và `\\[...\\]`. Phân số dài ở chế độ hiển thị độc lập có thanh cuộn ngang thay vì ép thu nhỏ không đọc được. Nếu công thức sai cú pháp, app thông báo lỗi và giữ văn bản gốc để người soạn sửa.

**Đồ thị/bảng biến thiên:** LaTeX không tự biến tất cả đồ thị thành hình. Với hình lớn, tải ảnh rõ nét lên kho ảnh được phép và điền trường `image_url` HTTPS; đảm bảo phép sử dụng và đọc được trên màn hình di động.

Font của tài liệu PDF gốc không được đóng gói lại; các công thức dùng bộ chữ toán của `flutter_math_fork`, phần giao diện dùng phông hệ thống Flutter để dễ đọc và không phân phối font không rõ giấy phép.
