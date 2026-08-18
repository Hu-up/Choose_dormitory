alter table public.audit_log enable row level security;

drop policy if exists "public insert audit log" on public.audit_log;

create policy "public insert audit log" on public.audit_log
  for insert with check (true);

grant insert on public.audit_log to anon;

create or replace function public.log_system_settings_change()
returns trigger
language plpgsql
security definer
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

select 'audit log rls fixed' as status;
