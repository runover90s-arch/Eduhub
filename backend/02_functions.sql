-- Functions for authenticated application operations. Run AFTER 01_schema.sql.
-- All SECURITY DEFINER RPCs check auth.uid and/or app_metadata explicitly.

create or replace function public.eh_start_attempt(p_exam_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid := (select auth.uid()); existing uuid; duration integer; session uuid;
begin
  if uid is null then raise exception 'Login required';end if;
  if not private.eh_can_exam(p_exam_id) then raise exception 'Exam not available for this account';end if;
  select duration_minutes into duration from public.eh_exams where id=p_exam_id;
  select id into existing from public.eh_exam_sessions
    where exam_id=p_exam_id and user_id=uid and status='active'
    order by started_at desc limit 1 for update;
  if existing is not null then
    if exists(select 1 from public.eh_exam_sessions s
      where s.id=existing and s.started_at + make_interval(mins=>duration+2) > now())
    then return existing;end if;
    update public.eh_exam_sessions set status='expired' where id=existing;
  end if;
  insert into public.eh_exam_sessions(user_id,exam_id)
    values(uid,p_exam_id) returning id into session;
  return session;
end $$;

create or replace function public.eh_save_draft(p_session uuid,p_answers jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare sess public.eh_exam_sessions%rowtype; duration integer;
begin
  if jsonb_typeof(p_answers)<>'object' or pg_column_size(p_answers)>120000
    then raise exception 'Invalid answer payload';end if;
  select * into sess from public.eh_exam_sessions
    where id=p_session and user_id=(select auth.uid()) and status='active' for update;
  if not found then raise exception 'Active exam session missing';end if;
  select duration_minutes into duration from public.eh_exams where id=sess.exam_id;
  if now() > sess.started_at+make_interval(mins=>duration) then
    return; -- Only drafts captured before the server deadline are accepted.
  end if;
  update public.eh_exam_sessions set last_draft=p_answers,updated_at=now() where id=p_session;
end $$;

create or replace function public.eh_log_incident(p_session uuid,p_kind text,p_event_key text)
returns boolean language plpgsql security definer set search_path='' as $$
declare sess public.eh_exam_sessions%rowtype;
begin
  if p_kind not in ('screen_off','app_background','multi_window','focus_lost')
     or length(p_event_key) not between 8 and 90 then raise exception 'Invalid event';end if;
  select * into sess from public.eh_exam_sessions
    where id=p_session and user_id=(select auth.uid()) and status='active';
  if not found then raise exception 'Session not active or not owned';end if;
  insert into public.eh_incidents(session_id,user_id,kind,event_key)
    values(p_session,sess.user_id,p_kind,p_event_key)
    on conflict(session_id,event_key) do nothing;
  return true;
end $$;

create or replace function public.eh_submit_attempt(p_session uuid,p_answers jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  sess public.eh_exam_sessions%rowtype;
  exam_minutes integer;
  ans jsonb;
  exp jsonb;
  explanation text;
  q public.eh_questions%rowtype;
  valid boolean;
  missing boolean;
  raw numeric := 0;
  maximum numeric := 0;
  score numeric := 0;
  penalties integer := 0;
  ncorrect integer := 0;
  nwrong integer := 0;
  nskip integer := 0;
  npending integer := 0;
  details jsonb := '{}'::jsonb;
  item_status text;
  result public.eh_attempts%rowtype;
begin
  if p_answers is null or jsonb_typeof(p_answers)<>'object' or pg_column_size(p_answers)>120000
    then raise exception 'Invalid answer payload';end if;
  select * into sess from public.eh_exam_sessions
    where id=p_session and user_id=(select auth.uid()) for update;
  if not found then raise exception 'Session missing or user mismatch';end if;
  if sess.status='submitted' then
    select * into result from public.eh_attempts where session_id=p_session;
    if found then return to_jsonb(result);end if;
    raise exception 'Already submitted';
  end if;
  if sess.status<>'active' then raise exception 'Session expired';end if;
  select duration_minutes into exam_minutes from public.eh_exams where id=sess.exam_id;
  -- If submission is late, do not grade answers written after the deadline.
  -- Last accepted server-saved draft is authoritative. G2 incidents still count.
  if now() > sess.started_at + make_interval(mins=>exam_minutes+1) then
    p_answers := sess.last_draft;
  else
    update public.eh_exam_sessions set last_draft=p_answers where id=p_session;
  end if;
  for q in select * from public.eh_questions where exam_id=sess.exam_id order by position loop
    maximum:=maximum+q.points;
    ans:=p_answers->(q.id::text);
    select k.answer,k.explanation into exp,explanation
      from public.eh_answer_keys k where question_id=q.id;
    missing := ans is null or jsonb_typeof(ans)='null' or ans='""'::jsonb or ans='[]'::jsonb or ans='{}'::jsonb;
    if q.kind='true_false' and jsonb_typeof(ans)='array' then
      missing := missing or exists(select 1 from jsonb_array_elements(ans) as a(value) where a.value='null'::jsonb);
    end if;
    if q.kind='matching' and jsonb_typeof(ans)='object' then
      missing := missing or exists(select 1 from jsonb_each(ans) as a(k,v) where a.v='null'::jsonb or a.v='""'::jsonb);
    end if;
    valid:=false;
    if missing then
      item_status:='skipped';nskip:=nskip+1;
    elsif q.kind='essay' then
      item_status:='pending';npending:=npending+1;
    else
      case q.kind
        when 'single' then valid:=ans=exp;
        when 'multiple' then valid:=jsonb_typeof(ans)='array' and jsonb_typeof(exp)='array'
          and jsonb_array_length(ans)=jsonb_array_length(exp) and ans@>exp and exp@>ans;
        when 'true_false' then valid:=ans=exp;
        when 'short' then
          if jsonb_typeof(ans)='string' and jsonb_typeof(exp)='string' then
            if replace(ans#>>'{}',',','.') ~ '^-?[0-9]+(\.[0-9]+)?$' and
               replace(exp#>>'{}',',','.') ~ '^-?[0-9]+(\.[0-9]+)?$'
            then valid := replace(ans#>>'{}',',','.')::numeric=replace(exp#>>'{}',',','.')::numeric;
            else valid := lower(trim(ans#>>'{}'))=lower(trim(exp#>>'{}'));end if;
          end if;
        when 'matching' then valid:=ans=exp;
        else valid:=false;
      end case;
      if valid then item_status:='correct';raw:=raw+q.points;ncorrect:=ncorrect+1;
      else item_status:='wrong';nwrong:=nwrong+1;end if;
    end if;
    details:=details||jsonb_build_object(q.id::text,jsonb_build_object(
      'position',q.position,'prompt',q.prompt,'kind',q.kind,'image_url',q.image_url,'options',q.options,
      'statements',q.statements,'pairs',q.pairs,'points',q.points,
      'status',item_status,'chosen',ans,'answer',case when q.kind='essay' then 'null'::jsonb else exp end,
      'explanation',coalesce(explanation,'')
    ));
  end loop;
  score := case when maximum>0 then round(10*raw/maximum,2) else 0 end;
  select count(*) into penalties from public.eh_incidents
    where session_id=p_session and waived_reason is null;
  insert into public.eh_attempts(session_id,exam_id,user_id,answers,raw_points,max_points,
    academic_score,penalty_count,final_score,correct_count,wrong_count,skipped_count,pending_count,details)
  values(p_session,sess.exam_id,sess.user_id,p_answers,raw,maximum,score,penalties,
    greatest(0,score-penalties),ncorrect,nwrong,nskip,npending,details)
  returning * into result;
  update public.eh_exam_sessions set status='submitted',submitted_at=now() where id=p_session;
  return to_jsonb(result);
end $$;

create or replace function public.eh_waive_incident(p_incident_id uuid,p_reason text)
returns boolean language plpgsql security definer set search_path='' as $$
declare sid uuid; updated_count integer;
begin
  if not private.eh_admin() then raise exception 'Admin required';end if;
  if length(trim(p_reason))<5 or length(p_reason)>500 then raise exception 'Valid reason required';end if;
  update public.eh_incidents set waived_reason=trim(p_reason),reviewed_by=(select auth.uid())
    where id=p_incident_id returning session_id into sid;
  if sid is null then raise exception 'Incident missing';end if;
  select count(*) into updated_count from public.eh_incidents where session_id=sid and waived_reason is null;
  update public.eh_attempts set penalty_count=updated_count,
    final_score=greatest(0,academic_score-updated_count)
    where session_id=sid;
  return true;
end $$;

create or replace function public.eh_grade_essay(p_session uuid,p_question_id uuid,p_awarded numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  attempt public.eh_attempts%rowtype;
  q public.eh_questions%rowtype;
  item jsonb;
  previous numeric:=0;
  updated_raw numeric;
  updated_score numeric;
  status text;
  ncorrect integer;
  nwrong integer;
  npending integer;
  result public.eh_attempts%rowtype;
begin
  if not private.eh_admin() then raise exception 'Admin required';end if;
  select * into attempt from public.eh_attempts where session_id=p_session for update;
  if not found then raise exception 'Attempt not found';end if;
  select * into q from public.eh_questions where id=p_question_id and exam_id=attempt.exam_id and kind='essay';
  if not found then raise exception 'Essay not found';end if;
  if p_awarded is null or p_awarded<0 or p_awarded>q.points then raise exception 'Invalid essay score';end if;
  item:=attempt.details->(p_question_id::text);
  if item is null or item->>'status' not in ('pending','graded','correct','wrong')
    then raise exception 'No submitted essay answer to grade';end if;
  previous:=coalesce((item->>'awarded')::numeric,0);
  updated_raw:=attempt.raw_points-previous+p_awarded;
  updated_score:=case when attempt.max_points>0 then round(10*updated_raw/attempt.max_points,2) else 0 end;
  status:=case when p_awarded=q.points then 'correct' else 'wrong' end;
  ncorrect:=attempt.correct_count+case when item->>'status'='correct' then -1 else 0 end+case when status='correct' then 1 else 0 end;
  nwrong:=attempt.wrong_count+case when item->>'status'='wrong' then -1 else 0 end+case when status='wrong' then 1 else 0 end;
  npending:=attempt.pending_count-case when item->>'status'='pending' then 1 else 0 end;
  update public.eh_attempts set
    raw_points=updated_raw,academic_score=updated_score,
    final_score=greatest(0,updated_score-penalty_count),
    correct_count=ncorrect,wrong_count=nwrong,pending_count=npending,
    details=jsonb_set(details,array[p_question_id::text],item||jsonb_build_object('status',status,'awarded',p_awarded,'graded',true))
    where session_id=p_session returning * into result;
  return to_jsonb(result);
end $$;

create or replace function public.eh_approve_order(p_order_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare ord public.eh_orders%rowtype; pack public.eh_packages%rowtype;
begin
  if not private.eh_admin() then raise exception 'Admin required';end if;
  select * into ord from public.eh_orders where id=p_order_id for update;
  if not found then raise exception 'Order missing';end if;
  if ord.status='approved' then return true;end if;
  if ord.status<>'pending' then raise exception 'Order is not pending';end if;
  select * into pack from public.eh_packages where id=ord.package_id;
  if not found or not pack.is_active then raise exception 'Package inactive';end if;
  insert into public.eh_entitlements(user_id,package_id,expires_at,granted_by)
    values(ord.user_id,ord.package_id,now()+make_interval(days=>pack.duration_days),(select auth.uid()))
    on conflict(user_id,package_id) do update set
      expires_at=greatest(public.eh_entitlements.expires_at,now())+make_interval(days=>pack.duration_days),
      granted_by=excluded.granted_by;
  update public.eh_orders set status='approved',reviewed_by=(select auth.uid()),reviewed_at=now() where id=ord.id;
  insert into public.eh_notifications(user_id,title,body)
    values(ord.user_id,'Gói học đã được kích hoạt','Quyền truy cập đã được quản trị viên cấp cho tài khoản của bạn.');
  return true;
end $$;

create or replace function public.eh_join_class(p_code text)
returns uuid language plpgsql security definer set search_path='' as $$
declare class_id uuid;uid uuid:=(select auth.uid());
begin
  if uid is null then raise exception 'Login required';end if;
  select c.id into class_id from public.eh_classes c where c.join_code=upper(trim(p_code));
  if class_id is null then raise exception 'Invalid class code';end if;
  insert into public.eh_class_members(class_id,user_id) values(class_id,uid)
    on conflict do nothing;
  return class_id;
end $$;

create or replace function public.eh_leaderboard(p_exam_id uuid)
returns table(display_name text,score numeric) language plpgsql
security definer set search_path='' as $$
begin
  if (select auth.uid()) is null then raise exception 'Login required';end if;
  return query
  select p.display_name,max(a.final_score)::numeric as score
    from public.eh_attempts a join public.eh_profiles p on p.id=a.user_id
    where a.exam_id=p_exam_id and p.leaderboard_opt_in=true
    group by p.id,p.display_name order by score desc,p.display_name limit 50;
end $$;

-- Authentication must be present for every function above.
revoke all on function public.eh_start_attempt(uuid),public.eh_save_draft(uuid,jsonb),
  public.eh_log_incident(uuid,text,text),public.eh_submit_attempt(uuid,jsonb),
  public.eh_waive_incident(uuid,text),public.eh_grade_essay(uuid,uuid,numeric),
  public.eh_approve_order(uuid),public.eh_join_class(text),public.eh_leaderboard(uuid)
  from public,anon;
grant execute on function public.eh_start_attempt(uuid),public.eh_save_draft(uuid,jsonb),
  public.eh_log_incident(uuid,text,text),public.eh_submit_attempt(uuid,jsonb),
  public.eh_waive_incident(uuid,text),public.eh_grade_essay(uuid,uuid,numeric),
  public.eh_approve_order(uuid),public.eh_join_class(text),public.eh_leaderboard(uuid)
  to authenticated;

-- Atomic question + answer-key creation. Prevents a draft containing a
-- half-saved question when the second client request fails.
create or replace function public.eh_admin_add_question(
  p_exam_id uuid,p_position integer,p_kind text,p_prompt text,
  p_options jsonb,p_statements jsonb,p_pairs jsonb,p_points numeric,
  p_answer jsonb,p_explanation text,p_image_url text
) returns uuid language plpgsql security definer set search_path='' as $$
declare state text;qid uuid;
begin
  if not private.eh_admin() then raise exception 'Admin required';end if;
  select status into state from public.eh_exams where id=p_exam_id for update;
  if state is distinct from 'draft' then raise exception 'Exam must be a draft';end if;
  if p_kind not in ('single','multiple','true_false','short','matching','essay')
    or length(trim(p_prompt))<4 or p_points<=0 or p_points>100
    then raise exception 'Invalid question';end if;
  if coalesce(p_image_url,'')<>'' and (p_image_url not like 'https://%' or length(p_image_url)>2048)
    then raise exception 'Image URL must be HTTPS';end if;
  if p_kind<>'essay' and (p_answer is null or p_answer='null'::jsonb)
    then raise exception 'Answer key is required';end if;
  if p_kind in ('single','multiple','matching') and jsonb_typeof(p_options)<>'array'
    then raise exception 'Options must be an array';end if;
  if p_kind='true_false' and jsonb_typeof(p_statements)<>'array'
    then raise exception 'Statements must be an array';end if;
  insert into public.eh_questions(exam_id,position,kind,prompt,options,statements,pairs,points,image_url)
  values(p_exam_id,p_position,p_kind,p_prompt,
    coalesce(p_options,'[]'::jsonb),coalesce(p_statements,'[]'::jsonb),coalesce(p_pairs,'[]'::jsonb),p_points,coalesce(p_image_url,''))
  returning id into qid;
  insert into public.eh_answer_keys(question_id,answer,explanation)
    values(qid,coalesce(p_answer,'{"manual":true}'::jsonb),coalesce(p_explanation,''));
  return qid;
end $$;
revoke all on function public.eh_admin_add_question(uuid,integer,text,text,jsonb,jsonb,jsonb,numeric,jsonb,text,text)
from public,anon;
grant execute on function public.eh_admin_add_question(uuid,integer,text,text,jsonb,jsonb,jsonb,numeric,jsonb,text,text)
to authenticated;

create or replace function public.eh_class_overview(p_class uuid)
returns table(exam_title text,learner_count bigint,submitted_count bigint,average_score numeric)
language plpgsql security definer set search_path='' as $$
begin
  if not private.eh_admin() and not exists(
    select 1 from public.eh_classes c where c.id=p_class and c.teacher_id=(select auth.uid())
  ) then raise exception 'Teacher access required';end if;
  return query
  select e.title,
    (select count(*) from public.eh_class_members m where m.class_id=p_class),
    count(distinct a.user_id),
    coalesce(round(avg(a.final_score),2),0)
  from public.eh_assignments assign
  join public.eh_exams e on e.id=assign.exam_id
  left join public.eh_class_members m on m.class_id=assign.class_id
  left join public.eh_attempts a on a.exam_id=assign.exam_id and a.user_id=m.user_id
  where assign.class_id=p_class
  group by assign.id,e.title;
end $$;
revoke all on function public.eh_class_overview(uuid) from public,anon;
grant execute on function public.eh_class_overview(uuid) to authenticated;
