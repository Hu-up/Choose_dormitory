create extension if not exists pgcrypto;

create table if not exists public.allowed_students (
  student_id text primary key check (student_id ~ '^120242227[0-9]{3}$'),
  name text not null,
  gender text not null check (gender in ('男', '女')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.system_settings (
  id text primary key default 'main',
  is_open boolean not null default false,
  opens_at timestamptz,
  closes_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint system_settings_singleton check (id = 'main'),
  constraint system_settings_time_order check (
    opens_at is null
    or closes_at is null
    or opens_at < closes_at
  )
);

insert into public.system_settings (id, is_open)
values ('main', false)
on conflict (id) do nothing;

create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  student_id text,
  student_name text,
  action text not null,
  old_dorm_id text,
  old_dorm_name text,
  new_dorm_id text,
  new_dorm_name text,
  detail text
);

create or replace function public.touch_system_settings_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists system_settings_touch_updated_at on public.system_settings;

create trigger system_settings_touch_updated_at
before update on public.system_settings
for each row
execute function public.touch_system_settings_updated_at();

create or replace function public.log_system_settings_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  insert into public.audit_log (
    action,
    detail
  )
  values (
    '系统设置',
    concat(
      '开放状态：', old.is_open, ' -> ', new.is_open,
      '；开始：', coalesce(old.opens_at::text, '-'), ' -> ', coalesce(new.opens_at::text, '-'),
      '；截止：', coalesce(old.closes_at::text, '-'), ' -> ', coalesce(new.closes_at::text, '-')
    )
  );
  return new;
end;
$$;

drop trigger if exists system_settings_audit_log on public.system_settings;

create trigger system_settings_audit_log
after update on public.system_settings
for each row
execute function public.log_system_settings_change();

create or replace function public.choose_dorm(
  p_name text,
  p_gender text,
  p_student_id text,
  p_dorm_id text
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

  select count(*)
    into v_occupied
    from public.records
    where dorm_id = p_dorm_id;

  if v_occupied >= v_dorm.capacity then
    return jsonb_build_object('status', 'full');
  end if;

  insert into public.records (name, gender, student_id, dorm_id)
  values (trim(p_name), p_gender, trim(p_student_id), p_dorm_id);

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
    '学生首次确认床位，确认后不可修改。'
  );

  return jsonb_build_object('status', 'created');
end;
$$;

alter table public.system_settings enable row level security;
alter table public.audit_log enable row level security;

drop policy if exists "public read system settings" on public.system_settings;
drop policy if exists "public update system settings" on public.system_settings;
drop policy if exists "public read audit log" on public.audit_log;

create policy "public read system settings" on public.system_settings
  for select using (true);

create policy "public update system settings" on public.system_settings
  for update using (true) with check (true);

create policy "public read audit log" on public.audit_log
  for select using (true);

drop policy if exists "public insert records" on public.records;
drop policy if exists "public update records" on public.records;
drop policy if exists "public delete records" on public.records;

revoke insert, update, delete on public.records from anon;

grant select on public.system_settings to anon;
grant update (is_open, opens_at, closes_at) on public.system_settings to anon;
grant select on public.audit_log to anon;
grant execute on function public.choose_dorm(text, text, text, text) to anon;

select
  'controls ready' as status,
  (select is_open from public.system_settings where id = 'main') as is_open,
  (select count(*) from public.audit_log) as audit_log_count;
