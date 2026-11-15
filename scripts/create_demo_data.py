import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]

def q(i,kind,prompt,answer,options=None,statements=None,pairs=None,explanation='',points=1):
    return dict(id=f'demo-q{i:02}',position=i,kind=kind,prompt=prompt,answer=answer,options=options or [],statements=statements or [],pairs=pairs or [],explanation=explanation,points=points)

math=[
 q(1,'single',r'Cho hàm số $f(x)=x^3-3x$. Giá trị của $f\'(2)$ bằng bao nhiêu?','C',
   ['3','6','9','12'],explanation=r'Ta có $f\'(x)=3x^2-3$, suy ra $f\'(2)=3\cdot 2^2-3=9$.'),
 q(2,'single',r'Cho $f\'(x)=(x+1)(x-2)$. Hàm số $f$ đồng biến trên khoảng nào?','C',
   [r'$(-1;2)$',r'$(0;2)$',r'$(2;+\infty)$',r'$(-2;1)$'],
   explanation=r'$f\'(x)>0$ khi $x<-1$ hoặc $x>2$.'),
 q(3,'true_false',r'Cho $y=x^3-3x$. Chọn đúng hoặc sai cho từng khẳng định.',
   [True,False,True,True],statements=[r'$y\'=3x^2-3$.',r'Hàm số đồng biến trên $(-1;1)$.',
   r'Hàm số có hai điểm cực trị.',r'$f(0)=0$.'],explanation=r'$y\'<0$ trên $(-1;1)$; đạo hàm đổi dấu ở $x=-1,1$.'),
 q(4,'short',r'Cho $f(x)=x^2-6x+14$. Tìm giá trị nhỏ nhất của $f$ trên $\mathbb{R}$.','5',
   explanation=r'$f(x)=(x-3)^2+5\geq5$. Dấu bằng xảy ra khi $x=3$.'),
 q(5,'multiple',r'Tìm tất cả các phương trình có nghiệm $x=2$. Chọn tất cả đáp án đúng.',
   ['A','C'],options=[r'$x^2-4=0$',r'$x^2+4=0$',r'$3x=6$',r'$x+1=4$'],
   explanation=r'Thay $x=2$ vào từng phương trình, ta thấy A và C đúng.'),
 q(6,'matching',r'Nối mỗi hàm số với đạo hàm tương ứng.',
   {'A':'2','B':'1','C':'3'},pairs=[{'left':r'$x^2$','right':'2','label':'A'},
   {'left':r'$\sin x$','right':'1','label':'B'},
   {'left':r'$e^x$','right':'3','label':'C'}],
   options=[r'$\cos x$',r'$2x$',r'$e^x$'],explanation=r'$(x^2)\'=2x$, $(\sin x)\'=\cos x$, $(e^x)\'=e^x$.'),
 q(7,'essay',r'Trình bày cách tìm các khoảng đơn điệu của $f(x)=x^3-3x^2+2$.',None,
   explanation='Giáo viên sẽ chấm bài tự luận dựa trên các bước: tính đạo hàm, lập bảng dấu và kết luận.',points=2),
]
exams=[{
'id':'math-12-demo','title':'TOÁN 12 – KHẢO SÁT HÀM SỐ','subject':'Toán học','grade':12,
'description':'Tính đơn điệu, cực trị, đạo hàm và phương trình. Có sáu dạng câu hỏi.',
'duration_minutes':40,'difficulty':'Trung bình','access_level':'free','status':'published','question_count':len(math),
'questions':math},
{
'id':'physics-11-demo','title':'VẬT LÍ 11 – ĐIỆN TRƯỜNG','subject':'Vật lí','grade':11,
'description':'Điện tích và cường độ điện trường, công của lực điện.',
'duration_minutes':20,'difficulty':'Cơ bản','access_level':'free','status':'published','question_count':3,
'questions':[
q(1,'single',r'Đơn vị của cường độ điện trường là gì?','B',options=['W','N/C','J','C'],explanation=r'$E=\frac{F}{q}$, đơn vị là N/C hoặc V/m.'),
q(2,'single',r'Điện tích $q=2\,\mathrm{C}$ đặt trong điện trường $E=5\,\mathrm{N/C}$. Lực tác dụng có độ lớn là bao nhiêu?','C',options=['2 N','5 N','10 N','20 N'],explanation=r'$F=|q|E=2\cdot5=10\,\mathrm{N}$.'),
q(3,'short',r'Từ $F=qE$, với $q=3$ và $E=4$, tìm $F$.','12',explanation=r'$F=3\cdot4=12$.'),
]},
{
'id':'chemistry-12-demo','title':'HÓA HỌC 12 – ESTE','subject':'Hóa học','grade':12,'description':'Cấu tạo và phản ứng thủy phân este.','duration_minutes':20,
'difficulty':'Cơ bản','access_level':'free','status':'published','question_count':2,
'questions':[q(1,'single','Chất nào sau đây là este?','C',options=['CH₃COOH','C₂H₅OH','CH₃COOCH₃','HCHO'],explanation='CH₃COOCH₃ là este.'),q(2,'short','Trong CH₃COOCH₃ có bao nhiêu nguyên tử oxygen?','2',explanation='Có hai nguyên tử O.')]},
{
'id':'math-12-pro','title':'ĐỀ CHUYÊN ĐỀ NÂNG CAO – TOÁN 12','subject':'Toán học','grade':12,
'description':'Bài tập có công thức LaTeX nâng cao, dành cho gói PRO.',
'duration_minutes':30,'difficulty':'Nâng cao','access_level':'pro','status':'published','question_count':2,
'questions':[q(1,'single',r'Tính $\displaystyle\int_0^1 2x\,\mathrm{d}x$.','B',options=['0','1','2','3'],explanation=r'$\left[x^2\right]_0^1=1$.'),q(2,'short',r'Giải $\sqrt{x+1}=3$. Tìm $x$.','8',explanation=r'$x+1=9$, do đó $x=8$.')]}
]
lessons=[
{'id':'lesson-monotone','title':'Tính đơn điệu của hàm số','subject':'Toán học','grade':12,'description':'Ôn tập dấu đạo hàm và bảng biến thiên.','access_level':'free','duration_minutes':18,'status':'published','body':r'''Mục tiêu bài học
Nắm được cách dùng đạo hàm để tìm các khoảng đơn điệu của hàm số.

Điều kiện đủ
Nếu $f'(x)>0$ với mọi $x\in(a;b)$ thì $f$ đồng biến trên $(a;b)$.
Nếu $f'(x)<0$ với mọi $x\in(a;b)$ thì $f$ nghịch biến trên $(a;b)$.

Ví dụ
Xét $f(x)=x^3-3x$. Ta có:
$$f'(x)=3x^2-3=3(x-1)(x+1).$$
Hàm số đồng biến trên $(-\infty;-1)$ và $(1;+\infty)$, nghịch biến trên $(-1;1)$.

Luyện tập
Với $g(x)=x^2-4x+3$, hãy lập bảng biến thiên.'''},
{'id':'lesson-integral','title':'Tích phân xác định','subject':'Toán học','grade':12,'description':'Công thức Newton–Leibniz và ví dụ.','access_level':'free','duration_minutes':15,'status':'published','body':r'''Định lí cơ bản
Nếu $F'(x)=f(x)$ liên tục trên $[a;b]$, thì
$$\int_a^b f(x)\,\mathrm{d}x=F(b)-F(a).$$

Ví dụ
$$\int_0^2 2x\,\mathrm{d}x=\left[x^2\right]_0^2=4.$$'''},
{'id':'lesson-electric','title':'Điện trường','subject':'Vật lí','grade':11,'description':'Vectơ cường độ điện trường.','access_level':'free','duration_minutes':12,'status':'published','body':r'''Cường độ điện trường
$$\vec E=\frac{\vec F}{q}$$
Đơn vị của cường độ điện trường: N/C hoặc V/m.

Lưu ý
Vectơ điện trường cùng chiều lực điện tác dụng lên điện tích thử dương.'''},
{'id':'lesson-advanced','title':'Ứng dụng đạo hàm nâng cao','subject':'Toán học','grade':12,'description':'Bài toán tối ưu và ứng dụng.','access_level':'pro','duration_minutes':25,'status':'published','body':r'Bài tập: Tìm $\min_{x>0}\left(x+\frac4x\right)$.'},
]
packages=[
{'id':'pro-month-demo','title':'EduHub PRO – 30 ngày','description':'Mở khóa toàn bộ đề và bài học PRO trong 30 ngày.','price_vnd':29000,'duration_days':30,'is_combo':False},
{'id':'pro-quarter-demo','title':'EduHub PRO – 90 ngày','description':'Truy cập nội dung PRO trong 90 ngày.','price_vnd':79000,'duration_days':90,'is_combo':False},
{'id':'math-combo-demo','title':'Combo Toán 12','description':'Bộ đề nâng cao và bài học ứng dụng đạo hàm.','price_vnd':39000,'duration_days':90,'is_combo':True}
]
def fix_typography(value):
    if isinstance(value, str):
        return value.replace(chr(92) + chr(39), chr(39))
    if isinstance(value,list):
        return [fix_typography(x) for x in value]
    if isinstance(value,dict):
        return {k:fix_typography(v) for k,v in value.items()}
    return value
out=fix_typography({'exams':exams,'lessons':lessons,'packages':packages})
path=root/'assets/data/demo.json'
path.write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'{path}: {path.stat().st_size} bytes; {len(exams)} exams, {sum(len(e["questions"]) for e in exams)} questions')
