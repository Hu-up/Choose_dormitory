insert into public.allowed_students (student_id, name, gender)
values ('120242227157', '孙晨', '男')
on conflict (student_id) do update
set name = excluded.name,
    gender = excluded.gender,
    updated_at = now();

delete from public.allowed_students
where student_id = '120242227362'
   or name = '易嘉耀';

insert into public.audit_log (
  student_id,
  student_name,
  action,
  detail
)
values (
  '120242227157',
  '孙晨',
  '名单修正',
  '将男生名单中的 120242227362 / 易嘉耀 修正为 120242227157 / 孙晨。'
);

select
  'student list updated' as status,
  (select count(*) from public.allowed_students where student_id = '120242227157' and name = '孙晨') as sunchen_count,
  (select count(*) from public.allowed_students where student_id = '120242227362' or name = '易嘉耀') as old_student_count,
  (select count(*) from public.records where student_id = '120242227362' or name = '易嘉耀') as old_record_count;
