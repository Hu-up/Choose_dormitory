alter table public.records
  add column if not exists bed_number integer;

alter table public.records
  drop constraint if exists records_bed_number_valid;

alter table public.records
  add constraint records_bed_number_valid
  check (bed_number is null or bed_number between 1 and 12);

create unique index if not exists records_dorm_bed_unique
  on public.records (dorm_id, bed_number)
  where bed_number is not null;

create or replace function public.choose_dorm(
  p_name text,
  p_gender text,
  p_student_id text,
  p_dorm_id text,
  p_bed_number integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_dorm public.dorms%rowtype;
  v_student public.allowed_students%rowtype;
  v_existing public.records%rowtype;
  v_settings public.system_settings%rowtype;
  v_occupied integer;
  v_bed_occupied integer;
begin
  select *
    into v_settings
    from public.system_settings
    where id = 'main';

  if not found or v_settings.is_open is not true then
    return jsonb_build_object('status', 'system_closed');
  end if;

  if v_settings.opens_at is not null and now() < v_settings.opens_at then
    return jsonb_build_object('status', 'not_started');
  end if;

  if v_settings.closes_at is not null and now() > v_settings.closes_at then
    return jsonb_build_object('status', 'ended');
  end if;

  if trim(p_student_id) !~ '^120242227[0-9]{3}$' then
    return jsonb_build_object('status', 'invalid_student_id');
  end if;

  perform pg_advisory_xact_lock(hashtext(lower(trim(p_student_id))));
  perform pg_advisory_xact_lock(hashtext(p_dorm_id || ':' || p_bed_number::text));

  select *
    into v_student
    from public.allowed_students
    where lower(student_id) = lower(trim(p_student_id));

  if not found then
    return jsonb_build_object('status', 'not_allowed');
  end if;

  if v_student.gender <> p_gender then
    return jsonb_build_object('status', 'student_gender_mismatch');
  end if;

  if trim(v_student.name) <> trim(p_name) then
    return jsonb_build_object('status', 'student_name_mismatch');
  end if;

  select *
    into v_existing
    from public.records
    where lower(student_id) = lower(trim(p_student_id))
    for update;

  if v_existing.id is not null then
    return jsonb_build_object('status', 'already_selected');
  end if;

  select *
    into v_dorm
    from public.dorms
    where id = p_dorm_id
    for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  if v_dorm.gender <> p_gender then
    return jsonb_build_object('status', 'gender_mismatch');
  end if;

  if p_bed_number is null
     or p_bed_number < 1
     or p_bed_number > v_dorm.capacity then
    return jsonb_build_object('status', 'invalid_bed_number');
  end if;

  select count(*)
    into v_bed_occupied
    from public.records
    where dorm_id = p_dorm_id
      and bed_number = p_bed_number;

  if v_bed_occupied > 0 then
    return jsonb_build_object('status', 'bed_taken');
  end if;

  select count(*)
    into v_occupied
    from public.records
    where dorm_id = p_dorm_id;

  if v_occupied >= v_dorm.capacity then
    return jsonb_build_object('status', 'full');
  end if;

  begin
    insert into public.records (name, gender, student_id, dorm_id, bed_number)
    values (trim(p_name), p_gender, trim(p_student_id), p_dorm_id, p_bed_number);
  exception
    when unique_violation then
      return jsonb_build_object('status', 'bed_taken');
  end;

  insert into public.audit_log (
    student_id,
    student_name,
    action,
    old_dorm_id,
    old_dorm_name,
    new_dorm_id,
    new_dorm_name,
    detail
  )
  values (
    trim(p_student_id),
    trim(p_name),
    '首次选择',
    null,
    null,
    v_dorm.id,
    v_dorm.name,
    concat('学生首次确认床位：', v_dorm.name, ' ', p_bed_number, '床。确认后不可修改。')
  );

  return jsonb_build_object('status', 'created');
end;
$$;

grant execute on function public.choose_dorm(text, text, text, text, integer) to anon;

select
  'bed selection ready' as status,
  (select count(*) from public.records where bed_number is null) as records_without_bed_number;
