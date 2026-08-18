delete from public.audit_log
where student_id in (
  '120242227137',
  '120242227139',
  '120242227151',
  '120242227153'
);

delete from public.records
where student_id in (
  '120242227137',
  '120242227139',
  '120242227151',
  '120242227153'
);

select
  'concurrency test cleaned' as status,
  (select count(*) from public.records where student_id in (
    '120242227137',
    '120242227139',
    '120242227151',
    '120242227153'
  )) as remaining_records,
  (select count(*) from public.audit_log where student_id in (
    '120242227137',
    '120242227139',
    '120242227151',
    '120242227153'
  )) as remaining_logs;
