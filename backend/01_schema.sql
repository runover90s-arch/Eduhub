-- EduHub Flutter v2.0 - new installation, run in Supabase SQL Editor.
-- Uses a distinct eh_ prefix; do NOT execute a full legacy EduHub schema first.
-- Public tables all enforce RLS. App authorization comes from app_metadata.
-- No payment credentials, AI endpoints, affiliate or financial wallet tables.

create extension if not exists pgcrypto;
create schema if not exists private;

create or replace function private.eh_admin() returns boolean
language sql stable set search_path = '' as $$
  select coalesce(auth.jwt()->'app_metadata'->>'role','') = 'admin'
$$;
create or replace function private.eh_teacher() returns boolean
language sql stable set search_path = '' as $$
  select coalesce(auth.jwt()->'app_metadata'->>'role','') in ('admin','teacher')
$$;

create table if not exists public.eh_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Học viên' check(length(display_name) <= 80),
  grade smallint check(grade between 1 and 12),
  leaderboard_opt_in boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.eh_packages (
  id uuid primary key default gen_random_uuid(),
  title text not null check(length(title) between 4 and 150),
  description text not null default '',
  price_vnd integer not null default 0 check(price_vnd between 0 and 100000000),
  duration_days integer not null default 30 check(duration_days between 1 and 3650),
  is_combo boolean not null default false,
  grants_all_pro boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.eh_entitlements (
  user_id uuid not null references auth.users(id) on delete cascade,
  package_id uuid not null references public.eh_packages(id),
  expires_at timestamptz not null,
  granted_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  primary key(user_id,package_id)
);
create table if not exists public.eh_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  package_id uuid not null references public.eh_packages(id),
  status text not null default 'pending' check(status in ('pending','approved','declined')),
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create table if not exists public.eh_exams (
  id uuid primary key default gen_random_uuid(),
  title text not null check(length(trim(title)) between 4 and 180),
  description text not null default '',
  subject text not null,
  grade smallint check(grade between 1 and 12),
  difficulty text not null default 'Trung bình',
  duration_minutes integer not null default 45 check(duration_minutes between 1 and 360),
  access_level text not null default 'free' check(access_level in ('free','pro')),
  status text not null default 'draft' check(status in ('draft','published','archived')),
  question_count integer not null default 0 check(question_count >= 0),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  published_at timestamptz
);
create table if not exists public.eh_questions (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.eh_exams(id) on delete cascade,
  position integer not null check(position between 1 and 2000),
  kind text not null check(kind in ('single','multiple','true_false','short','matching','essay')),
  prompt text not null check(length(trim(prompt)) between 4 and 15000),
  image_url text not null default '' check(length(image_url)<=2048 and (image_url='' or image_url like 'https://%')),
  options jsonb not null default '[]'::jsonb check(jsonb_typeof(options)='array'),
  statements jsonb not null default '[]'::jsonb check(jsonb_typeof(statements)='array'),
  pairs jsonb not null default '[]'::jsonb check(jsonb_typeof(pairs)='array'),
  points numeric(6,2) not null default 1 check(points > 0 and points <= 100),
  unique(exam_id,position)
);
create table if not exists public.eh_answer_keys (
  question_id uuid primary key references public.eh_questions(id) on delete cascade,
  answer jsonb not null,
  explanation text not null default ''
);
create table if not exists public.eh_package_exams (
  package_id uuid not null references public.eh_packages(id) on delete cascade,
  exam_id uuid not null references public.eh_exams(id) on delete cascade,
  primary key(package_id,exam_id)
);
create table if not exists public.eh_lessons (
  id uuid primary key default gen_random_uuid(),
  title text not null check(length(trim(title)) between 4 and 180),
  description text not null default '',
  subject text not null,
  grade smallint check(grade between 1 and 12),
  duration_minutes integer not null default 15 check(duration_minutes between 1 and 600),
  access_level text not null default 'free' check(access_level in ('free','pro')),
  status text not null default 'draft' check(status in ('draft','published','archived')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create table if not exists public.eh_lesson_bodies (
  lesson_id uuid primary key references public.eh_lessons(id) on delete cascade,
  body text not null default ''
);
create table if not exists public.eh_package_lessons (
  package_id uuid not null references public.eh_packages(id) on delete cascade,
  lesson_id uuid not null references public.eh_lessons(id) on delete cascade,
  primary key(package_id,lesson_id)
);
create table if not exists public.eh_lesson_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id uuid not null references public.eh_lessons(id) on delete cascade,
  note text not null default '' check(length(note)<=20000),
  completed boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key(user_id,lesson_id)
);
create table if not exists public.eh_exam_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exam_id uuid not null references public.eh_exams(id),
  started_at timestamptz not null default now(),
  status text not null default 'active' check(status in ('active','submitted','expired')),
  last_draft jsonb not null default '{}'::jsonb check(jsonb_typeof(last_draft)='object'),
  updated_at timestamptz not null default now(),
  submitted_at timestamptz
);
create unique index if not exists eh_one_active_session on public.eh_exam_sessions(user_id,exam_id) where status='active';
create table if not exists public.eh_incidents (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.eh_exam_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check(kind in ('screen_off','app_background','multi_window','focus_lost')),
  event_key text not null check(length(event_key) between 8 and 90),
  waived_reason text,
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique(session_id,event_key)
);
create table if not exists public.eh_attempts (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null unique references public.eh_exam_sessions(id),
  exam_id uuid not null references public.eh_exams(id),
  user_id uuid not null references auth.users(id) on delete cascade,
  answers jsonb not null check(jsonb_typeof(answers)='object'),
  raw_points numeric(9,2) not null default 0,
  max_points numeric(9,2) not null default 0,
  academic_score numeric(5,2) not null default 0,
  penalty_count integer not null default 0,
  final_score numeric(5,2) not null default 0,
  correct_count integer not null default 0,
  wrong_count integer not null default 0,
  skipped_count integer not null default 0,
  pending_count integer not null default 0,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table if not exists public.eh_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null, body text not null default '',
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.eh_classes (
  id uuid primary key default gen_random_uuid(),
  name text not null check(length(trim(name)) between 3 and 100),
  teacher_id uuid not null references auth.users(id),
  join_code text not null unique default upper(substr(encode(gen_random_bytes(6),'hex'),1,7)),
  created_at timestamptz not null default now()
);
create table if not exists public.eh_class_members (
  class_id uuid not null references public.eh_classes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(class_id,user_id)
);
create table if not exists public.eh_assignments (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.eh_classes(id) on delete cascade,
  exam_id uuid not null references public.eh_exams(id),
  due_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists eh_exams_published_idx on public.eh_exams(status,subject,created_at desc);
create index if not exists eh_questions_exam_idx on public.eh_questions(exam_id,position);
create index if not exists eh_attempts_user_idx on public.eh_attempts(user_id,created_at desc);
create index if not exists eh_incidents_session_idx on public.eh_incidents(session_id);

-- Profile trigger runs on the privileged Auth table; this function is private
-- and not exposed through Data API/RPC.
create or replace function private.eh_new_profile() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  insert into public.eh_profiles(id,display_name)
  values(new.id,coalesce(nullif(left(new.raw_user_meta_data->>'full_name',80),''),'Học viên'))
  on conflict(id) do nothing;
  return new;
end $$;
drop trigger if exists eh_on_signup on auth.users;
create trigger eh_on_signup after insert on auth.users for each row execute function private.eh_new_profile();

-- Existing Auth users who registered before this schema was installed:
insert into public.eh_profiles(id,display_name)
select id,coalesce(nullif(left(raw_user_meta_data->>'full_name',80),''),'Học viên') from auth.users
on conflict(id) do nothing;

create or replace function private.eh_can_exam(p_exam uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.eh_exams x
    where x.id=p_exam and x.status='published' and (
      x.access_level='free' or exists (
        select 1 from public.eh_entitlements e
        join public.eh_packages p on p.id=e.package_id
        where e.user_id=(select auth.uid()) and e.expires_at>now()
          and (p.grants_all_pro or exists(
            select 1 from public.eh_package_exams pe
            where pe.exam_id=x.id and pe.package_id=e.package_id
          ))
      )
    )
  )
$$;
create or replace function private.eh_can_lesson(p_lesson uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.eh_lessons l
    where l.id=p_lesson and l.status='published' and (
      l.access_level='free' or exists (
        select 1 from public.eh_entitlements e
        join public.eh_packages p on p.id=e.package_id
        where e.user_id=(select auth.uid()) and e.expires_at>now()
          and (p.grants_all_pro or exists(
            select 1 from public.eh_package_lessons pl
            where pl.lesson_id=l.id and pl.package_id=e.package_id
          ))
      )
    )
  )
$$;
create or replace function private.eh_member(p_class uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.eh_classes c where c.id=p_class and c.teacher_id=(select auth.uid()))
     or exists(select 1 from public.eh_class_members m where m.class_id=p_class and m.user_id=(select auth.uid()))
$$;

create or replace function private.eh_question_count() returns trigger
language plpgsql set search_path='' as $$
declare eid uuid;
begin
  eid=case when tg_op='DELETE' then old.exam_id else new.exam_id end;
  update public.eh_exams set question_count=(
    select count(*) from public.eh_questions where exam_id=eid
  ) where id=eid;
  if tg_op='DELETE' then return old;else return new;end if;
end $$;
drop trigger if exists eh_question_sync on public.eh_questions;
create trigger eh_question_sync after insert or delete on public.eh_questions
for each row execute function private.eh_question_count();

-- A published exam is immutable until archived or returned to draft.
create or replace function private.eh_edit_draft() returns trigger
language plpgsql set search_path='' as $$
declare eid uuid; is_draft boolean;
begin
  if tg_table_name='eh_questions' then
    eid=case when tg_op='DELETE' then old.exam_id else new.exam_id end;
  else
    select exam_id into eid from public.eh_questions where id=case when tg_op='DELETE' then old.question_id else new.question_id end;
  end if;
  if eid is null and tg_op='DELETE' then return old; end if;
  select (status='draft') into is_draft from public.eh_exams where id=eid;
  if is_draft is false then raise exception 'Chuyen de ve ban nhap truoc khi sua cau hoi';end if;
  if tg_op='DELETE' then return old;else return new;end if;
end $$;
drop trigger if exists eh_questions_draft on public.eh_questions;
create trigger eh_questions_draft before insert or update or delete on public.eh_questions
for each row execute function private.eh_edit_draft();
drop trigger if exists eh_keys_draft on public.eh_answer_keys;
create trigger eh_keys_draft before insert or update or delete on public.eh_answer_keys
for each row execute function private.eh_edit_draft();

-- Publishing is deliberately stricter than drafting. No key, malformed letter,
-- mismatched true/false array, or incomplete match may go live.
create or replace function private.eh_publish_valid() returns trigger
language plpgsql set search_path='' as $$
declare q public.eh_questions%rowtype; k jsonb; n integer; count_question integer:=0;
begin
  if new.status='published' and (tg_op='INSERT' or old.status is distinct from 'published') then
    for q in select * from public.eh_questions where exam_id=new.id order by position loop
      count_question:=count_question+1;
      select answer into k from public.eh_answer_keys where question_id=q.id;
      if q.kind<>'essay' and (k is null or k='null'::jsonb)
        then raise exception 'Cau % thieu dap an',q.position;end if;
      if q.kind in ('single','multiple') then
        n:=jsonb_array_length(q.options);
        if n<2 or n>20 then raise exception 'Cau % thieu phuong an',q.position;end if;
        if q.kind='single' then
          if jsonb_typeof(k)<>'string' or length(k#>>'{}')<>1 or
            ascii(k#>>'{}')<65 or ascii(k#>>'{}')>=65+n
          then raise exception 'Cau % dap an ABCD khong hop le',q.position;end if;
        else
          if jsonb_typeof(k)<>'array' then raise exception 'Cau % dap an nhieu lua chon phai la mang',q.position;end if;
          if jsonb_array_length(k)<1 then raise exception 'Cau % chua chon dap an',q.position;end if;
          if (select count(*) from jsonb_array_elements_text(k) el
            where length(el.value)<>1 or ascii(el.value)<65 or ascii(el.value)>=65+n)>0
          or (select count(*) from jsonb_array_elements_text(k))<>
             (select count(distinct el.value) from jsonb_array_elements_text(k) el)
          then raise exception 'Cau % dap an lua chon khong hop le',q.position;end if;
        end if;
      elsif q.kind='true_false' then
        n:=jsonb_array_length(q.statements);
        if n<1 or n>20 or jsonb_typeof(k)<>'array'
          then raise exception 'Cau % mang dung sai khong hop le',q.position;end if;
        if jsonb_array_length(k)<>n or exists(
          select 1 from jsonb_array_elements(k) el where jsonb_typeof(el.value)<>'boolean')
        then raise exception 'Cau % so dap an dung sai khong khop',q.position;end if;
      elsif q.kind='short' then
        if jsonb_typeof(k)<>'string' or length(trim(k#>>'{}'))=0
          then raise exception 'Cau % thieu dap an ngan',q.position;end if;
      elsif q.kind='matching' then
        if jsonb_typeof(k)<>'object' or jsonb_array_length(q.pairs)<1 or
          jsonb_array_length(q.options)<2 then raise exception 'Cau % cap noi khong hop le',q.position;end if;
        if (select count(*) from jsonb_each(k))<>jsonb_array_length(q.pairs) then
          raise exception 'Cau % thieu dap an noi',q.position;end if;
        if exists (select 1 from jsonb_each_text(k) kv
          where kv.value !~ '^[0-9]+$' or kv.value::integer<1 or
            kv.value::integer>jsonb_array_length(q.options))
        then raise exception 'Cau % vi tri ghep noi khong hop le',q.position;end if;
      end if;
    end loop;
    if count_question=0 then raise exception 'De thi chua co cau hoi';end if;
    new.published_at=now();
  end if;
  return new;
end $$;
drop trigger if exists eh_check_publish on public.eh_exams;
create trigger eh_check_publish before insert or update of status on public.eh_exams
for each row execute function private.eh_publish_valid();

-- Row Level Security on EVERY exposed table.
do $$
declare name text;
begin
  foreach name in array array[
    'eh_profiles','eh_packages','eh_entitlements','eh_orders','eh_exams','eh_questions',
    'eh_answer_keys','eh_package_exams','eh_lessons','eh_lesson_bodies',
    'eh_package_lessons','eh_lesson_progress','eh_exam_sessions','eh_incidents',
    'eh_attempts','eh_notifications','eh_classes','eh_class_members','eh_assignments'
  ] loop execute format('alter table public.%I enable row level security',name); end loop;
end $$;

create policy eh_profiles_own_read on public.eh_profiles for select to authenticated
using(id=(select auth.uid()) or private.eh_admin());
create policy eh_profiles_own_update on public.eh_profiles for update to authenticated
using(id=(select auth.uid())) with check(id=(select auth.uid()));

create policy eh_packages_live on public.eh_packages for select to anon,authenticated using(is_active);
create policy eh_packages_admin on public.eh_packages for all to authenticated
using(private.eh_admin()) with check(private.eh_admin());

create policy eh_entitlements_own on public.eh_entitlements for select to authenticated
using(user_id=(select auth.uid()) or private.eh_admin());
create policy eh_entitlements_admin_write on public.eh_entitlements for all to authenticated
using(private.eh_admin()) with check(private.eh_admin());

create policy eh_orders_own on public.eh_orders for select to authenticated
using(user_id=(select auth.uid()) or private.eh_admin());
create policy eh_orders_create on public.eh_orders for insert to authenticated
with check(user_id=(select auth.uid()) and status='pending');
create policy eh_orders_admin_update on public.eh_orders for update to authenticated
using(private.eh_admin()) with check(private.eh_admin());

create policy eh_exams_public on public.eh_exams for select to anon,authenticated using(status='published');
create policy eh_exams_editor on public.eh_exams for all to authenticated
using(private.eh_admin()) with check(private.eh_admin());
create policy eh_questions_view on public.eh_questions for select to authenticated
using(private.eh_can_exam(exam_id) or private.eh_admin());
create policy eh_questions_admin_write on public.eh_questions for all to authenticated
using(private.eh_admin()) with check(private.eh_admin());
create policy eh_keys_admin on public.eh_answer_keys for all to authenticated
using(private.eh_admin()) with check(private.eh_admin());
create policy eh_package_exams_select on public.eh_package_exams for select to authenticated using(true);
create policy eh_package_exams_admin on public.eh_package_exams for all to authenticated
using(private.eh_admin()) with check(private.eh_admin());

create policy eh_lessons_public on public.eh_lessons for select to anon,authenticated using(status='published');
create policy eh_lessons_admin on public.eh_lessons for all to authenticated
using(private.eh_admin()) with check(private.eh_admin());
create policy eh_lesson_body_read on public.eh_lesson_bodies for select to authenticated
using(private.eh_can_lesson(lesson_id) or private.eh_admin());
create policy eh_lesson_body_admin on public.eh_lesson_bodies for all to authenticated
using(private.eh_admin()) with check(private.eh_admin());
create policy eh_package_lessons_select on public.eh_package_lessons for select to authenticated using(true);
create policy eh_package_lessons_admin on public.eh_package_lessons for all to authenticated
using(private.eh_admin()) with check(private.eh_admin());
create policy eh_progress_owner on public.eh_lesson_progress for all to authenticated
using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));

create policy eh_sessions_own_read on public.eh_exam_sessions for select to authenticated
using(user_id=(select auth.uid()) or private.eh_admin());
create policy eh_incidents_read on public.eh_incidents for select to authenticated
using(user_id=(select auth.uid()) or private.eh_admin());
create policy eh_attempts_read on public.eh_attempts for select to authenticated
using(user_id=(select auth.uid()) or private.eh_admin());
create policy eh_notifications_read on public.eh_notifications for select to authenticated
using(user_id=(select auth.uid()) or private.eh_admin());
create policy eh_notifications_update on public.eh_notifications for update to authenticated
using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy eh_notifications_admin on public.eh_notifications for insert to authenticated
with check(private.eh_admin());

create policy eh_classes_select on public.eh_classes for select to authenticated
using(private.eh_member(id) or private.eh_admin());
create policy eh_classes_create on public.eh_classes for insert to authenticated
with check(private.eh_teacher() and teacher_id=(select auth.uid()));
create policy eh_classes_update on public.eh_classes for update to authenticated
using(teacher_id=(select auth.uid()) or private.eh_admin()) with check(teacher_id=(select auth.uid()) or private.eh_admin());
create policy eh_members_read on public.eh_class_members for select to authenticated
using(user_id=(select auth.uid()) or private.eh_member(class_id) or private.eh_admin());
create policy eh_members_teacher on public.eh_class_members for delete to authenticated
using(private.eh_admin() or exists(select 1 from public.eh_classes c where c.id=class_id and c.teacher_id=(select auth.uid())));
create policy eh_assignments_read on public.eh_assignments for select to authenticated
using(private.eh_member(class_id) or private.eh_admin());
create policy eh_assignments_create on public.eh_assignments for insert to authenticated
with check(private.eh_admin() or exists(select 1 from public.eh_classes c where c.id=class_id and c.teacher_id=(select auth.uid())));

-- Revoke default Data API privileges and grant only the requested operations.
-- RLS still applies to all grants below.
do $$
declare name text;
begin
  foreach name in array array[
    'eh_profiles','eh_packages','eh_entitlements','eh_orders','eh_exams','eh_questions',
    'eh_answer_keys','eh_package_exams','eh_lessons','eh_lesson_bodies',
    'eh_package_lessons','eh_lesson_progress','eh_exam_sessions','eh_incidents',
    'eh_attempts','eh_notifications','eh_classes','eh_class_members','eh_assignments'
  ] loop execute format('revoke all on public.%I from anon, authenticated',name); end loop;
end $$;
grant select on public.eh_exams,public.eh_lessons,public.eh_packages to anon,authenticated;
grant select on public.eh_profiles,public.eh_orders,public.eh_entitlements,
  public.eh_questions,public.eh_answer_keys,public.eh_package_exams,
  public.eh_lesson_bodies,public.eh_package_lessons,public.eh_lesson_progress,
  public.eh_attempts,public.eh_exam_sessions,public.eh_incidents,
  public.eh_notifications,public.eh_classes,public.eh_class_members,public.eh_assignments
  to authenticated;
grant insert on public.eh_exams,public.eh_questions,public.eh_answer_keys,public.eh_lessons,
  public.eh_lesson_bodies,public.eh_orders,public.eh_lesson_progress,public.eh_classes,
  public.eh_assignments,public.eh_packages,public.eh_package_exams,public.eh_package_lessons
  to authenticated;
grant update on public.eh_profiles,public.eh_exams,public.eh_questions,public.eh_answer_keys,
  public.eh_lessons,public.eh_lesson_bodies,public.eh_lesson_progress,public.eh_notifications,
  public.eh_orders,public.eh_packages,public.eh_classes
  to authenticated;
grant delete on public.eh_questions,public.eh_answer_keys,public.eh_package_exams,
  public.eh_package_lessons,public.eh_assignments to authenticated;

grant usage on schema private to authenticated;
grant execute on function private.eh_admin() to authenticated;
grant execute on function private.eh_teacher() to authenticated;
grant execute on function private.eh_can_exam(uuid) to authenticated;
grant execute on function private.eh_can_lesson(uuid) to authenticated;
grant execute on function private.eh_member(uuid) to authenticated;
revoke all on function private.eh_new_profile() from public,anon,authenticated;
