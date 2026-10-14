-- Preserve existing reviewer IDs, answers, and long-code recovery.
alter table audit_private.unique_reviewers add column short_code text unique check(short_code ~ '^[A-HJ-NP-Z2-9]{4}$');
create or replace function public.audit_identity(p_code text default null,p_new boolean default false) returns uuid language plpgsql security definer set search_path='' as $$
declare normalized text;rid uuid;uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'Sign in first';end if;
 if p_code is null then select reviewer_id into rid from audit_private.unique_sessions where user_id=uid;if rid is null then raise exception 'No saved identity';end if;return rid;end if;
 normalized:=regexp_replace(upper(p_code),'[[:space:]-]','','g');
 if normalized !~ '^([A-HJ-NP-Z2-9]{4}|[A-HJ-NP-Z2-9]{20})$' then raise exception 'Invalid recovery code';end if;
 if p_new then
  insert into audit_private.unique_reviewers(code_hash,short_code) values(encode(extensions.digest(normalized,'sha256'),'hex'),case when length(normalized)=4 then normalized else null end) returning id into rid;
  insert into public.audit_reviews(reviewer_id,packet_id) values(rid,'7a4473668931765a3c9d');
 else
  select id into rid from audit_private.unique_reviewers where short_code=normalized or code_hash=encode(extensions.digest(normalized,'sha256'),'hex');
  if rid is null then raise exception 'Recovery code not found';end if;
 end if;
 insert into audit_private.unique_sessions values(uid,rid) on conflict(user_id) do update set reviewer_id=excluded.reviewer_id;
 return rid;
end $$;
create function public.audit_short_code(p_reviewer uuid) returns text language plpgsql security definer set search_path='' as $$
declare result text;alphabet text:='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';bytes bytea;i integer;
begin
 if not public.audit_owns_review(p_reviewer) then raise exception 'Reviewer access required';end if;
 select short_code into result from audit_private.unique_reviewers where id=p_reviewer for update;
 if result is not null then return result;end if;
 loop
  bytes:=extensions.gen_random_bytes(4);result:='';
  for i in 0..3 loop result:=result||substr(alphabet,(get_byte(bytes,i)%32)+1,1);end loop;
  begin update audit_private.unique_reviewers set short_code=result where id=p_reviewer;return result;
  exception when unique_violation then null;
  end;
 end loop;
end $$;
revoke all on function public.audit_short_code(uuid) from public;
grant execute on function public.audit_short_code(uuid) to authenticated;
