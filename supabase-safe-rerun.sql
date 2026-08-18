create extension if not exists pgcrypto;

create table if not exists public.dorms (
  id text primary key,
  name text not null unique,
  gender text not null check (gender in ('男', '女')),
  capacity integer not null check (capacity > 0),
  created_at timestamptz not null default now()
);

create table if not exists public.records (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  gender text not null check (gender in ('男', '女')),
  student_id text not null,
  dorm_id text not null references public.dorms(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.records_backup_before_schema_fix as
select *
from public.records
where false;

insert into public.records_backup_before_schema_fix
select r.*
from public.records r
where not exists (
  select 1
  from public.records_backup_before_schema_fix b
  where b.id = r.id
);

delete from public.records
where student_id !~ '^120242227[0-9]{3}$';

delete from public.records r
using (
  select id,
         row_number() over (
           partition by lower(student_id)
           order by updated_at desc, created_at desc, id desc
         ) as rn
  from public.records
) ranked
where r.id = ranked.id
  and ranked.rn > 1;

drop index if exists public.records_student_unique;
drop index if exists public.records_student_id_unique;

create unique index if not exists records_student_id_unique
  on public.records (lower(student_id));

alter table public.records
  drop constraint if exists records_student_id_format;

alter table public.records
  add constraint records_student_id_format
  check (student_id ~ '^120242227[0-9]{3}$');

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists records_touch_updated_at on public.records;

create trigger records_touch_updated_at
before update on public.records
for each row
execute function public.touch_updated_at();

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
  v_existing public.records%rowtype;
  v_occupied integer;
  v_status text;
begin
  if trim(p_student_id) !~ '^120242227[0-9]{3}$' then
    return jsonb_build_object('status', 'invalid_student_id');
  end if;

  perform pg_advisory_xact_lock(hashtext(lower(trim(p_student_id))));

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

  select *
    into v_existing
    from public.records
    where lower(student_id) = lower(trim(p_student_id))
    for update;

  if v_existing.id is not null and lower(v_existing.name) <> lower(trim(p_name)) then
    return jsonb_build_object('status', 'duplicate_student_id');
  end if;

  select count(*)
    into v_occupied
    from public.records
    where dorm_id = p_dorm_id
      and (v_existing.id is null or id <> v_existing.id);

  if v_occupied >= v_dorm.capacity then
    return jsonb_build_object('status', 'full');
  end if;

  if v_existing.id is null then
    insert into public.records (name, gender, student_id, dorm_id)
    values (trim(p_name), p_gender, trim(p_student_id), p_dorm_id);
    v_status := 'created';
  else
    update public.records
      set name = trim(p_name),
          gender = p_gender,
          student_id = trim(p_student_id),
          dorm_id = p_dorm_id
      where id = v_existing.id;
    v_status := 'updated';
  end if;

  return jsonb_build_object('status', v_status);
end;
$$;

alter table public.dorms enable row level security;
alter table public.records enable row level security;

drop policy if exists "public read dorms" on public.dorms;
drop policy if exists "public insert dorms" on public.dorms;
drop policy if exists "public update dorms" on public.dorms;
drop policy if exists "public delete dorms" on public.dorms;
drop policy if exists "public read records" on public.records;
drop policy if exists "public insert records" on public.records;
drop policy if exists "public update records" on public.records;
drop policy if exists "public delete records" on public.records;

create policy "public read dorms" on public.dorms
  for select using (true);

create policy "public insert dorms" on public.dorms
  for insert with check (true);

create policy "public update dorms" on public.dorms
  for update using (true) with check (true);

create policy "public delete dorms" on public.dorms
  for delete using (true);

create policy "public read records" on public.records
  for select using (true);

create policy "public insert records" on public.records
  for insert with check (true);

create policy "public update records" on public.records
  for update using (true) with check (true);

create policy "public delete records" on public.records
  for delete using (true);

grant usage on schema public to anon;
grant select, insert, update, delete on public.dorms to anon;
grant select, insert, update, delete on public.records to anon;
grant execute on function public.choose_dorm(text, text, text, text) to anon;

select
  'schema ready' as status,
  (select count(*) from public.dorms) as dorm_count,
  (select count(*) from public.records) as valid_record_count,
  (select count(*) from public.records_backup_before_schema_fix) as backed_up_record_count;
