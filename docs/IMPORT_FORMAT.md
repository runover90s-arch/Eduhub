# Định dạng nhập đề EduHub Studio

Bạn có thể dán nội dung JSON vào **EduHub Studio → Đề thi → Nhập đề hàng loạt (JSON)**. Bộ nhập không trực tiếp đọc PDF, DOCX; cần chuyển sang JSON và rà soát công thức/đáp án.

**Ví dụ tối thiểu**:

```json
{
  "title": "Ôn tập Toán 12 – Đạo hàm",
  "subject": "Toán học",
  "description": "Kiểm tra kiến thức chương I",
  "grade": 12,
  "duration_minutes": 40,
  "difficulty": "Trung bình",
  "access_level": "free",
  "questions": [
    {
      "kind": "single",
      "prompt": "Cho $f(x)=x^2$. Đạo hàm $f'(x)$ là?",
      "options": ["$x$", "$2x$", "$x^2$", "$1$"],
      "answer": "B",
      "explanation": "$(x^2)'=2x$.",
      "points": 1
    },
    {
      "kind": "true_false",
      "prompt": "Xét các phát biểu sau",
      "statements": ["$f'(x)=2x$", "$f(2)=8$"],
      "answer": [true, false],
      "points": 1
    },
    {
      "kind": "short",
      "prompt": "Tính $f(3)$ với $f(x)=x^2$.",
      "answer": "9"
    },
    {
      "kind": "essay",
      "prompt": "Giải thích công thức đạo hàm bằng định nghĩa giới hạn.",
      "points": 2
    }
  ]
}
```

Các `kind` được nhận là `single`, `multiple`, `true_false`, `short`, `matching`, `essay`.

- `single`: có `options` 2–20 phần tử, `answer` là chữ `A`, `B`, `C`... (từ A theo đúng số phương án).
- `multiple`: có `options`, `answer` là mảng chữ không trùng, ví dụ `["A", "C"]`.
- `true_false`: `statements` 1–20 phát biểu, `answer` là mảng boolean tương ứng, ví dụ `[true,false,true]`.
- `short`: `answer` là chuỗi hoặc số; phần mềm hỗ trợ dấu phẩy/dấu chấm thập phân khi chấm, ví dụ `"2,5"`.
- `matching`: `options` là vế phải, `pairs` là danh sách `{"label":"A","left":"..."}` và `answer` là đối tượng map vị trí vế phải (bắt đầu từ `"1"`): `{"A":"2","B":"1"}`.
- `essay`: không yêu cầu đáp án tự động, chấm thủ công trong Studio.
- `image_url`: tùy chọn, URL ảnh `https://` truy cập được trên thiết bị; không nên dùng link cần cookie hoặc đăng nhập.
- `points`: trọng số câu (mặc định `1`). Theo bản hiện tại, đúng/sai theo ý là **đúng toàn bộ hoặc sai toàn bộ**, không dùng thang điểm từng ý của mọi kỳ thi. Điều chỉnh theo quy chế đề nếu cần.

Nội dung toán dùng LaTeX với `$...$` hoặc `$$...$$`. Trên JSON, ký tự `\` trong lệnh LaTeX phải gõ thành `\\`, ví dụ `"$\\frac{x+1}{2}$"`.

Sau khi nhấn **Nhập**, đề luôn ở trạng thái **nháp**; nếu kết nối lỗi giữa chừng, bản nháp có thể chứa một phần câu và phải kiểm tra lại trong Studio trước khi công bố. Backend kiểm tra đáp án khi chuyển trạng thái sang `published`.
