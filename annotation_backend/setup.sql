-- Run once in the Supabase SQL editor. Enable anonymous sign-ins in Auth.
create schema if not exists audit_private;
create extension if not exists pgcrypto with schema extensions;
create table audit_private.invites (code_hash text primary key, reviewer text unique not null check (reviewer in ('A','B')), used_by uuid unique);
create table audit_private.reviewers (user_id uuid primary key references auth.users(id), reviewer text unique not null check (reviewer in ('A','B')));
revoke all on schema audit_private from public, anon, authenticated;
create table public.audit_progress (
 user_id uuid primary key references auth.users(id),
 packet_id text not null check (packet_id='7a4473668931765a3c9d'),
 labels jsonb not null default '{}'::jsonb,
 task_position integer not null default 0 check(task_position between 0 and 187),
 revision integer not null default 0,
 updated_at timestamptz not null default now()
);
alter table public.audit_progress enable row level security;
revoke all on public.audit_progress from anon, authenticated;
grant select on public.audit_progress to authenticated;
create policy own_progress on public.audit_progress for select to authenticated using (user_id=(select auth.uid()));
create function public.audit_join(p_code text) returns text language plpgsql security definer set search_path='' as $$
declare r text; used uuid; uid uuid := auth.uid();
begin
 if uid is null then raise exception 'Sign in first'; end if;
 select reviewer into r from audit_private.reviewers where user_id=uid;
 if r is not null then return r; end if;
 select reviewer,used_by into r,used from audit_private.invites where code_hash=encode(extensions.digest(p_code,'sha256'),'hex') for update;
 if r is null or (used is not null and used<>uid) then raise exception 'Invalid or already used review code'; end if;
 insert into audit_private.reviewers values(uid,r);
 update audit_private.invites set used_by=uid where reviewer=r;
 insert into public.audit_progress(user_id,packet_id) values(uid,'7a4473668931765a3c9d');
 return r;
end $$;
create function public.audit_save(p_packet text,p_labels jsonb,p_position integer,p_revision integer) returns integer language plpgsql security definer set search_path='' as $$
declare next_revision integer; item record; field text; value text;
begin
 if not exists(select 1 from audit_private.reviewers where user_id=auth.uid()) then raise exception 'Reviewer access required'; end if;
 if p_packet<>'7a4473668931765a3c9d' or jsonb_typeof(p_labels)<>'object' then raise exception 'Invalid packet or labels'; end if;
 for item in select * from jsonb_each(p_labels) loop
  if item.key !~ '^C(00[1-9]|0[1-9][0-9]|[12][0-9]{2}|3[0-6][0-9]|37[0-6])$' or jsonb_typeof(item.value)<>'object' then raise exception 'Invalid case'; end if;
  for field,value in select key,value from jsonb_each_text(item.value) loop
   if field='reason' then
    if jsonb_typeof(item.value->field)<>'string' or length(value)>10000 then raise exception 'Invalid note'; end if;
   elsif field in ('restaurant_requirements','requested_information','normal_ending') then
    if jsonb_typeof(item.value->field)<>'string' or value not in ('','yes','no','cannot determine') then raise exception 'Invalid answer'; end if;
   else raise exception 'Invalid field'; end if;
  end loop;
 end loop;
 update public.audit_progress set labels=p_labels,task_position=p_position,revision=revision+1,updated_at=now() where user_id=auth.uid() and packet_id=p_packet and revision=p_revision returning revision into next_revision;
 if next_revision is null then raise exception 'Progress changed in another session. Reload before saving'; end if;
 return next_revision;
end $$;
revoke all on function public.audit_join(text),public.audit_save(text,jsonb,integer,integer) from public;
grant execute on function public.audit_join(text),public.audit_save(text,jsonb,integer,integer) to authenticated;
-- Generate the two private codes separately; do not commit the returned codes.
-- select encode(extensions.gen_random_bytes(24),'hex') as review_code;
-- Insert the SHA-256 hash of each code, assigning exactly one to A and one to B:
-- insert into audit_private.invites(code_hash,reviewer) values(encode(extensions.digest('REPLACE_WITH_PRIVATE_CODE','sha256'),'hex'),'A');
