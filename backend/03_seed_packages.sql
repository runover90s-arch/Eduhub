-- OPTIONAL sample packages for a fresh Supabase project.
-- These are listing prices, NOT payment integration or payment proof.
insert into public.eh_packages(id,title,description,price_vnd,duration_days,is_combo,grants_all_pro)
values
 ('fdadd009-8a33-4d91-b44b-273000000001','EduHub PRO - 30 ngày','Toàn bộ bài học và đề PRO trong 30 ngày.',29000,30,false,true),
 ('fdadd009-8a33-4d91-b44b-273000000002','EduHub PRO - 90 ngày','Truy cập bài học và đề PRO trong 90 ngày.',79000,90,false,true),
 ('fdadd009-8a33-4d91-b44b-273000000003','Combo Toán 12','Chọn các đề Toán 12 và bài học nâng cao trong Studio.',39000,90,true,false)
on conflict(id) do nothing;
-- WARNING: Combo has no content until its exam/lesson mappings are configured.
