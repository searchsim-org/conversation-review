-- Add unique reviewers without changing existing A/B records.
create table audit_private.unique_reviewers (id uuid primary key default gen_random_uuid(), code_hash text unique not null);
create table audit_private.unique_sessions (user_id uuid primary key references auth.users(id), reviewer_id uuid not null references audit_private.unique_reviewers(id));
alter table audit_private.unique_reviewers enable row level security;
alter table audit_private.unique_sessions enable row level security;
create table public.audit_reviews (reviewer_id uuid primary key references audit_private.unique_reviewers(id), packet_id text not null check(packet_id='7a4473668931765a3c9d'), labels jsonb not null default '{}'::jsonb, task_position integer not null default 0 check(task_position between 0 and 187), revision integer not null default 0, updated_at timestamptz not null default now());
alter table public.audit_reviews enable row level security;
revoke all on public.audit_reviews from anon,authenticated;
grant select on public.audit_reviews to authenticated;
create function public.audit_owns_review(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from audit_private.unique_sessions where user_id=auth.uid() and reviewer_id=p_id) $$;
revoke all on function public.audit_owns_review(uuid) from public;
grant execute on function public.audit_owns_review(uuid) to authenticated;
create policy own_unique_review on public.audit_reviews for select to authenticated using(public.audit_owns_review(reviewer_id));
create function public.audit_identity(p_code text default null,p_new boolean default false) returns uuid language plpgsql security definer set search_path='' as $$
declare normalized text; rid uuid; uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'Sign in first';end if;
 if p_code is null then select reviewer_id into rid from audit_private.unique_sessions where user_id=uid;if rid is null then raise exception 'No saved identity';end if;return rid;end if;
 normalized:=regexp_replace(upper(p_code),'[[:space:]-]','','g');
 if normalized !~ '^[A-HJ-NP-Z2-9]{20}$' then raise exception 'Invalid recovery code';end if;
 if p_new then
  insert into audit_private.unique_reviewers(code_hash) values(encode(extensions.digest(normalized,'sha256'),'hex')) returning id into rid;
  insert into public.audit_reviews(reviewer_id,packet_id) values(rid,'7a4473668931765a3c9d');
 else
  select id into rid from audit_private.unique_reviewers where code_hash=encode(extensions.digest(normalized,'sha256'),'hex');
  if rid is null then raise exception 'Recovery code not found';end if;
 end if;
 insert into audit_private.unique_sessions values(uid,rid) on conflict(user_id) do update set reviewer_id=excluded.reviewer_id;
 return rid;
end $$;
create function public.audit_save_review(p_reviewer uuid,p_packet text,p_labels jsonb,p_position integer,p_revision integer) returns integer language plpgsql security definer set search_path='' as $$
declare next_revision integer;item record;field text;value text;
begin
 if not public.audit_owns_review(p_reviewer) then raise exception 'Reviewer access required';end if;
 if p_packet<>'7a4473668931765a3c9d' or jsonb_typeof(p_labels)<>'object' then raise exception 'Invalid packet or labels';end if;
 for item in select * from jsonb_each(p_labels) loop
  if item.key !~ '^C(00[1-9]|0[1-9][0-9]|[12][0-9]{2}|3[0-6][0-9]|37[0-6])$' or jsonb_typeof(item.value)<>'object' then raise exception 'Invalid case';end if;
  for field,value in select j.key,j.value from jsonb_each_text(item.value) as j loop
   if field='reason' then if jsonb_typeof(item.value->field)<>'string' or length(value)>10000 then raise exception 'Invalid note';end if;
   elsif field in ('restaurant_requirements','requested_information','normal_ending') then if jsonb_typeof(item.value->field)<>'string' or value not in ('','yes','no','cannot determine') then raise exception 'Invalid answer';end if;
   else raise exception 'Invalid field';end if;
  end loop;
 end loop;
 update public.audit_reviews set labels=p_labels,task_position=p_position,revision=revision+1,updated_at=now() where reviewer_id=p_reviewer and packet_id=p_packet and revision=p_revision returning revision into next_revision;
 if next_revision is null then raise exception 'Progress changed in another session. Reload before saving';end if;return next_revision;
end $$;
revoke all on function public.audit_identity(text,boolean),public.audit_save_review(uuid,text,jsonb,integer,integer) from public;
grant execute on function public.audit_identity(text,boolean),public.audit_save_review(uuid,text,jsonb,integer,integer) to authenticated;
