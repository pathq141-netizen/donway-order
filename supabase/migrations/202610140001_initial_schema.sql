-- Donway initial production schema. Deliberately contains no business seed data.
create extension if not exists pgcrypto;
create type public.account_status as enum ('active','blocked','suspended');
create type public.order_status as enum ('pending','processing','completed','failed','cancelled','refunded');
create type public.topup_status as enum ('pending','approved','rejected','expired');
create type public.wallet_tx_type as enum ('credit','debit','refund','admin_adjustment','topup');

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '', phone text, avatar_path text,
 role text not null default 'user' check (role in ('user','admin')),
 status public.account_status not null default 'active', deleted_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.product_categories (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 1 and 100), slug text not null unique,
 description text not null default '', is_active boolean not null default false, sort_order integer not null default 0,
 deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.products (
 id uuid primary key default gen_random_uuid(), category_id uuid references public.product_categories(id), name text not null check(length(trim(name)) between 1 and 120),
 description text not null default '', price numeric(14,2) not null check(price>=0), stock_quantity integer not null default 0 check(stock_quantity>=0),
 image_path text, is_active boolean not null default false, sort_order integer not null default 0, is_digital boolean not null default false,
 deleted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.product_stock (
 id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id), secret_payload jsonb not null,
 status text not null default 'available' check(status in ('available','reserved','sold','disabled')), reserved_order_id uuid,
 created_at timestamptz not null default now(), sold_at timestamptz
);
create table public.wallets (
 user_id uuid primary key references public.profiles(id), balance numeric(14,2) not null default 0 check(balance>=0), updated_at timestamptz not null default now()
);
create table public.orders (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id), status public.order_status not null default 'pending',
 subtotal numeric(14,2) not null check(subtotal>=0), discount numeric(14,2) not null default 0 check(discount>=0), total numeric(14,2) not null check(total>=0),
 idempotency_key text not null, failure_reason text, cancellation_reason text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(user_id,idempotency_key)
);
alter table public.product_stock add constraint product_stock_reserved_order_fk foreign key(reserved_order_id) references public.orders(id);
create table public.order_items (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id), product_id uuid references public.products(id),
 product_name text not null, unit_price numeric(14,2) not null check(unit_price>=0), quantity integer not null check(quantity>0), line_total numeric(14,2) not null check(line_total>=0), created_at timestamptz not null default now()
);
create table public.wallet_transactions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id), type public.wallet_tx_type not null,
 amount numeric(14,2) not null check(amount>0), balance_after numeric(14,2) not null check(balance_after>=0), reference_type text not null,
 reference_id uuid, idempotency_key text not null, description text not null default '', actor_id uuid references public.profiles(id), created_at timestamptz not null default now(),
 unique(user_id,idempotency_key)
);
create table public.topup_requests (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id), amount numeric(14,2) not null check(amount>0),
 status public.topup_status not null default 'pending', payment_reference text, duration_minutes integer not null check(duration_minutes between 1 and 10080),
 expires_at timestamptz not null, reviewed_by uuid references public.profiles(id), reviewed_at timestamptz, review_reason text,
 idempotency_key text not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(user_id,idempotency_key)
);
create table public.vouchers (
 id uuid primary key default gen_random_uuid(), code text not null unique, discount_amount numeric(14,2) not null check(discount_amount>=0),
 max_redemptions integer check(max_redemptions is null or max_redemptions>0), per_user_limit integer not null default 1 check(per_user_limit>0),
 starts_at timestamptz, expires_at timestamptz, is_active boolean not null default false, created_at timestamptz not null default now()
);
create table public.voucher_redemptions (
 id uuid primary key default gen_random_uuid(), voucher_id uuid not null references public.vouchers(id), user_id uuid not null references public.profiles(id),
 order_id uuid references public.orders(id), discount_amount numeric(14,2) not null check(discount_amount>=0), idempotency_key text not null,
 created_at timestamptz not null default now(), unique(voucher_id,user_id,idempotency_key)
);
create table public.store_settings (key text primary key, value jsonb not null, updated_by uuid references public.profiles(id), updated_at timestamptz not null default now());
create table public.announcements (id uuid primary key default gen_random_uuid(), title text not null, body text not null, is_active boolean not null default false, starts_at timestamptz, ends_at timestamptz, created_by uuid references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.user_restrictions (id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id), restriction_type text not null, config jsonb not null default '{}', reason text not null, active boolean not null default true, created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(), ends_at timestamptz);
create table public.user_topup_settings (user_id uuid primary key references public.profiles(id), override_enabled boolean not null default false, duration_minutes integer not null check(duration_minutes between 1 and 10080), reason text not null, updated_by uuid not null references public.profiles(id), updated_at timestamptz not null default now());
create table public.admin_audit_logs (id uuid primary key default gen_random_uuid(), actor_id uuid references public.profiles(id), action text not null, entity_type text not null, entity_id uuid, metadata jsonb not null default '{}', created_at timestamptz not null default now());
create table public.notifications (id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id), title text not null, body text not null, read_at timestamptz, created_at timestamptz not null default now());
create table public.notification_outbox (id uuid primary key default gen_random_uuid(), event_type text not null, payload jsonb not null, status text not null default 'pending' check(status in ('pending','processing','sent','failed')), attempts integer not null default 0 check(attempts>=0), next_attempt_at timestamptz not null default now(), last_error text, created_at timestamptz not null default now(), sent_at timestamptz);
create index products_active_category_idx on public.products(is_active,category_id,sort_order) where deleted_at is null;
create index orders_user_created_idx on public.orders(user_id,created_at desc);
create index orders_status_created_idx on public.orders(status,created_at desc);
create index topup_user_created_idx on public.topup_requests(user_id,created_at desc);
create index topup_pending_expiry_idx on public.topup_requests(expires_at) where status='pending';
create index wallet_tx_user_created_idx on public.wallet_transactions(user_id,created_at desc);
create index audit_created_idx on public.admin_audit_logs(created_at desc);
create index notifications_user_created_idx on public.notifications(user_id,created_at desc);

create or replace function public.set_updated_at() returns trigger language plpgsql set search_path=pg_catalog as $$ begin new.updated_at=now(); return new; end $$;
create trigger profiles_updated before update on public.profiles for each row execute function public.set_updated_at();
create trigger categories_updated before update on public.product_categories for each row execute function public.set_updated_at();
create trigger products_updated before update on public.products for each row execute function public.set_updated_at();
create trigger orders_updated before update on public.orders for each row execute function public.set_updated_at();
create trigger topups_updated before update on public.topup_requests for each row execute function public.set_updated_at();

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
begin
 insert into public.profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'display_name','')) on conflict(id) do nothing;
 insert into public.wallets(user_id,balance) values(new.id,0) on conflict(user_id) do nothing;
 return new;
end $$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Atomic checkout. Prices and stock are loaded/locked from database; never accepted from browser.
create or replace function public.checkout(p_items jsonb,p_idempotency_key text) returns uuid
language plpgsql security definer set search_path=pg_catalog,public as $$
declare uid uuid:=auth.uid(); oid uuid; item jsonb; p public.products%rowtype; qty integer; subtotal numeric(14,2):=0; total numeric(14,2); current_balance numeric(14,2); existing uuid;
begin
 if uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_idempotency_key is null or length(p_idempotency_key)<12 or length(p_idempotency_key)>128 then raise exception 'INVALID_IDEMPOTENCY_KEY'; end if;
 select id into existing from public.orders where user_id=uid and idempotency_key=p_idempotency_key; if existing is not null then return existing; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 or jsonb_array_length(p_items)>30 then raise exception 'INVALID_ITEMS'; end if;
 for item in select value from jsonb_array_elements(p_items) loop
  if (item->>'quantity') !~ '^[1-9][0-9]{0,3}$' then raise exception 'INVALID_QUANTITY'; end if;
  qty:=(item->>'quantity')::integer;
  select * into p from public.products where id=(item->>'product_id')::uuid and is_active and deleted_at is null for update;
  if not found then raise exception 'PRODUCT_UNAVAILABLE'; end if;
  if p.stock_quantity<qty then raise exception 'INSUFFICIENT_STOCK'; end if;
  subtotal:=subtotal+p.price*qty;
 end loop;
 total:=subtotal;
 select balance into current_balance from public.wallets where user_id=uid for update;
 if current_balance is null or current_balance<total then raise exception 'INSUFFICIENT_BALANCE'; end if;
 insert into public.orders(user_id,status,subtotal,total,idempotency_key) values(uid,'processing',subtotal,total,p_idempotency_key) returning id into oid;
 for item in select value from jsonb_array_elements(p_items) loop
  qty:=(item->>'quantity')::integer;
  update public.products set stock_quantity=stock_quantity-qty where id=(item->>'product_id')::uuid and stock_quantity>=qty returning * into p;
  if not found then raise exception 'INSUFFICIENT_STOCK'; end if;
  insert into public.order_items(order_id,product_id,product_name,unit_price,quantity,line_total) values(oid,p.id,p.name,p.price,qty,p.price*qty);
 end loop;
 update public.wallets set balance=balance-total,updated_at=now() where user_id=uid returning balance into current_balance;
 insert into public.wallet_transactions(user_id,type,amount,balance_after,reference_type,reference_id,idempotency_key,description) values(uid,'debit',total,current_balance,'order',oid,'checkout:'||p_idempotency_key,'Pembelian Donway');
 insert into public.notification_outbox(event_type,payload) values('order.created',jsonb_build_object('order_id',oid,'user_id',uid,'total',total));
 return oid;
end $$;
revoke all on function public.checkout(jsonb,text) from public,anon;
grant execute on function public.checkout(jsonb,text) to authenticated;

-- Admin identity must be assigned by trusted SQL operator using the exact auth.users UUID.
-- Never expose a self-service role escalation endpoint.
create or replace function public.admin_approve_topup(p_request_id uuid,p_reason text default '') returns void
language plpgsql security definer set search_path=pg_catalog,public as $$
declare actor uuid:=auth.uid(); t public.topup_requests%rowtype; bal numeric(14,2);
begin
 if actor is null or not exists(select 1 from public.profiles where id=actor and role='admin' and status='active') then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select * into t from public.topup_requests where id=p_request_id for update;
 if not found or t.status<>'pending' then raise exception 'TOPUP_NOT_PENDING'; end if;
 if t.expires_at<=now() then update public.topup_requests set status='expired',reviewed_by=actor,reviewed_at=now(),review_reason='Kedaluwarsa' where id=t.id; insert into public.admin_audit_logs(actor_id,action,entity_type,entity_id,metadata) values(actor,'topup.expire','topup_request',t.id,jsonb_build_object('reason','Kedaluwarsa')); return; end if;
 update public.wallets set balance=balance+t.amount,updated_at=now() where user_id=t.user_id returning balance into bal;
 if bal is null then raise exception 'WALLET_NOT_FOUND'; end if;
 update public.topup_requests set status='approved',reviewed_by=actor,reviewed_at=now(),review_reason=left(p_reason,500) where id=t.id;
 insert into public.wallet_transactions(user_id,type,amount,balance_after,reference_type,reference_id,idempotency_key,description,actor_id) values(t.user_id,'topup',t.amount,bal,'topup',t.id,'topup-approved:'||t.id,'Top up disetujui',actor);
 insert into public.admin_audit_logs(actor_id,action,entity_type,entity_id,metadata) values(actor,'topup.approve','topup_request',t.id,jsonb_build_object('amount',t.amount,'reason',left(p_reason,500)));
 insert into public.notification_outbox(event_type,payload) values('topup.approved',jsonb_build_object('topup_id',t.id,'user_id',t.user_id,'amount',t.amount));
end $$;
revoke all on function public.admin_approve_topup(uuid,text) from public,anon;
grant execute on function public.admin_approve_topup(uuid,text) to authenticated;

alter table public.profiles enable row level security;
alter table public.product_categories enable row level security;
alter table public.products enable row level security;
alter table public.product_stock enable row level security;
alter table public.wallets enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.topup_requests enable row level security;
alter table public.vouchers enable row level security;
alter table public.voucher_redemptions enable row level security;
alter table public.store_settings enable row level security;
alter table public.announcements enable row level security;
alter table public.user_restrictions enable row level security;
alter table public.user_topup_settings enable row level security;
alter table public.admin_audit_logs enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_outbox enable row level security;
create policy profile_read_self on public.profiles for select to authenticated using(id=auth.uid());
create policy profile_update_self on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid() and role='user');
create policy categories_public_active on public.product_categories for select to anon,authenticated using(is_active and deleted_at is null);
create policy products_public_active on public.products for select to anon,authenticated using(is_active and deleted_at is null and exists(select 1 from public.product_categories c where c.id=category_id and c.is_active and c.deleted_at is null));
create policy wallets_read_self on public.wallets for select to authenticated using(user_id=auth.uid());
create policy orders_read_self on public.orders for select to authenticated using(user_id=auth.uid());
create policy order_items_read_owner on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and o.user_id=auth.uid()));
create policy wallet_transactions_read_self on public.wallet_transactions for select to authenticated using(user_id=auth.uid());
create policy topups_read_self on public.topup_requests for select to authenticated using(user_id=auth.uid());
create policy vouchers_public_active on public.vouchers for select to authenticated using(is_active and (starts_at is null or starts_at<=now()) and (expires_at is null or expires_at>now()));
create policy notifications_read_self on public.notifications for select to authenticated using(user_id=auth.uid());
create policy announcements_public_active on public.announcements for select to anon,authenticated using(is_active and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>now()));
-- No client policies for stock secrets, writes to financial tables, admin logs, restrictions, settings, or outbox.

-- Restrict profile edits to explicitly allowed columns; never permit role/status mutation from client.
revoke update on public.profiles from anon, authenticated;
grant update(display_name,phone,avatar_path) on public.profiles to authenticated;
drop policy if exists profile_update_self on public.profiles;
create policy profile_update_self on public.profiles for update to authenticated using(id=auth.uid() and status='active') with check(id=auth.uid() and role='user' and status='active');

-- Server-time expiry and duration snapshot for each newly requested manual top up.
create or replace function public.create_topup_request(p_amount numeric,p_idempotency_key text)
returns uuid language plpgsql security definer set search_path=pg_catalog,public as $$
declare uid uuid:=auth.uid(); duration integer; override_row public.user_topup_settings%rowtype; req_id uuid; limit_cfg jsonb;
begin
 if uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
 if p_amount is null or p_amount<=0 or p_amount>100000000 then raise exception 'INVALID_AMOUNT'; end if;
 if p_idempotency_key is null or length(p_idempotency_key)<12 or length(p_idempotency_key)>128 then raise exception 'INVALID_IDEMPOTENCY_KEY'; end if;
 if exists(select 1 from public.topup_requests where user_id=uid and idempotency_key=p_idempotency_key) then select id into req_id from public.topup_requests where user_id=uid and idempotency_key=p_idempotency_key; return req_id; end if;
 if not exists(select 1 from public.profiles where id=uid and status='active') then raise exception 'ACCOUNT_RESTRICTED'; end if;
 select duration_minutes into duration from public.store_settings where key='topup_default_duration_minutes'; duration:=coalesce(duration,30);
 select * into override_row from public.user_topup_settings where user_id=uid and override_enabled;
 if found then duration:=override_row.duration_minutes; end if;
 if duration<1 or duration>10080 then raise exception 'INVALID_DURATION_CONFIGURATION'; end if;
 if exists(select 1 from public.user_restrictions where user_id=uid and active and restriction_type='topup_block' and (ends_at is null or ends_at>now())) then raise exception 'TOPUP_RESTRICTED'; end if;
 insert into public.topup_requests(user_id,amount,duration_minutes,expires_at,idempotency_key) values(uid,p_amount,duration,now()+make_interval(mins=>duration),p_idempotency_key) returning id into req_id;
 insert into public.notification_outbox(event_type,payload) values('topup.created',jsonb_build_object('topup_id',req_id,'user_id',uid,'amount',p_amount));
 return req_id;
end $$;
revoke all on function public.create_topup_request(numeric,text) from public,anon;
grant execute on function public.create_topup_request(numeric,text) to authenticated;

-- Storage bucket and policies: public catalog images only, with uploads restricted to active admins.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('donway-product-images','donway-product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy product_images_public_read on storage.objects for select to anon,authenticated using(bucket_id='donway-product-images');
create policy product_images_admin_insert on storage.objects for insert to authenticated with check(bucket_id='donway-product-images' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin' and p.status='active'));
create policy product_images_admin_update on storage.objects for update to authenticated using(bucket_id='donway-product-images' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin' and p.status='active')) with check(bucket_id='donway-product-images' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin' and p.status='active'));
create policy product_images_admin_delete on storage.objects for delete to authenticated using(bucket_id='donway-product-images' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin' and p.status='active'));
