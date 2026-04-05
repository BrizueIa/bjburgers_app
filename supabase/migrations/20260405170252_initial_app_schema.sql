create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.settings (
  id uuid primary key default gen_random_uuid(),
  business_name text not null default 'BJ Burguers',
  admin_pin text not null default '1234',
  admin_mode_enabled boolean not null default false,
  digital_menu_image_url text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.ingredients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  unit_name text not null default 'unidad',
  current_unit_cost numeric(12, 2) not null default 0,
  is_active boolean not null default true,
  device_id text,
  sync_status text not null default 'synced',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category_name text,
  product_type text not null check (product_type in ('simple', 'recipe')),
  sale_price numeric(12, 2) not null default 0,
  direct_cost numeric(12, 2) not null default 0,
  is_active boolean not null default true,
  display_order integer not null default 0,
  device_id text,
  sync_status text not null default 'synced',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);

create table if not exists public.product_recipe_items (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id) on delete restrict,
  quantity_used numeric(12, 3) not null default 0,
  is_optional boolean not null default false,
  device_id text,
  sync_status text not null default 'synced',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (product_id, ingredient_id)
);

create table if not exists public.ingredient_purchases (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.ingredients(id) on delete restrict,
  purchased_quantity numeric(12, 3) not null,
  total_cost numeric(12, 2) not null,
  unit_cost numeric(12, 2) not null,
  note text,
  purchased_at timestamptz not null default timezone('utc', now()),
  device_id text,
  sync_status text not null default 'synced',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null,
  status text not null default 'pending' check (status in ('pending', 'preparing', 'ready', 'delivered', 'cancelled')),
  notes text,
  total_estimated numeric(12, 2) not null default 0,
  device_id text,
  sync_status text not null default 'pending',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (order_number)
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name_snapshot text not null,
  unit_price_snapshot numeric(12, 2) not null default 0,
  base_cost_snapshot numeric(12, 2) not null default 0,
  quantity integer not null default 1,
  notes text,
  removed_ingredients_json jsonb not null default '[]'::jsonb,
  device_id text,
  sync_status text not null default 'pending',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  sale_number text not null,
  source_order_id uuid references public.orders(id) on delete set null,
  total_amount numeric(12, 2) not null default 0,
  estimated_cost numeric(12, 2) not null default 0,
  estimated_profit numeric(12, 2) not null default 0,
  payment_method text not null check (payment_method in ('cash', 'transfer')),
  paid_amount numeric(12, 2) not null default 0,
  change_amount numeric(12, 2) not null default 0,
  sold_at timestamptz not null default timezone('utc', now()),
  device_id text,
  sync_status text not null default 'pending',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (sale_number)
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name_snapshot text not null,
  unit_price_snapshot numeric(12, 2) not null default 0,
  unit_cost_snapshot numeric(12, 2) not null default 0,
  quantity integer not null default 1,
  line_total numeric(12, 2) not null default 0,
  line_cost_total numeric(12, 2) not null default 0,
  device_id text,
  sync_status text not null default 'pending',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);

create table if not exists public.cash_sessions (
  id uuid primary key default gen_random_uuid(),
  opened_at timestamptz not null default timezone('utc', now()),
  opening_amount numeric(12, 2) not null default 0,
  closed_at timestamptz,
  closing_expected_cash numeric(12, 2),
  closing_real_cash numeric(12, 2),
  transfer_total numeric(12, 2) not null default 0,
  difference_amount numeric(12, 2),
  status text not null default 'open' check (status in ('open', 'closed')),
  note text,
  device_id text,
  sync_status text not null default 'pending',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);

create table if not exists public.cash_movements (
  id uuid primary key default gen_random_uuid(),
  cash_session_id uuid not null references public.cash_sessions(id) on delete cascade,
  movement_type text not null check (movement_type in ('opening', 'sale', 'deposit', 'withdrawal', 'adjustment', 'closing')),
  payment_method text check (payment_method in ('cash', 'transfer')),
  amount numeric(12, 2) not null default 0,
  note text,
  reference_type text,
  reference_id uuid,
  device_id text,
  sync_status text not null default 'pending',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);

create table if not exists public.app_assets (
  id uuid primary key default gen_random_uuid(),
  asset_type text not null,
  remote_url text,
  local_path text,
  device_id text,
  sync_status text not null default 'pending',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.sync_queue (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  operation_type text not null check (operation_type in ('insert', 'update', 'delete')),
  payload_json jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'processing', 'failed', 'done')),
  retry_count integer not null default 0,
  last_error text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists settings_singleton_idx on public.settings ((true));
create index if not exists ingredients_name_idx on public.ingredients (name);
create index if not exists products_name_idx on public.products (name);
create index if not exists ingredient_purchases_ingredient_id_idx on public.ingredient_purchases (ingredient_id, purchased_at desc);
create index if not exists product_recipe_items_product_id_idx on public.product_recipe_items (product_id);
create index if not exists orders_status_created_at_idx on public.orders (status, created_at desc);
create index if not exists sales_sold_at_idx on public.sales (sold_at desc);
create index if not exists cash_sessions_status_idx on public.cash_sessions (status);
create index if not exists sync_queue_status_idx on public.sync_queue (status, created_at asc);

drop trigger if exists settings_set_updated_at on public.settings;
create trigger settings_set_updated_at
before update on public.settings
for each row execute function public.set_updated_at();

drop trigger if exists ingredients_set_updated_at on public.ingredients;
create trigger ingredients_set_updated_at
before update on public.ingredients
for each row execute function public.set_updated_at();

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

drop trigger if exists product_recipe_items_set_updated_at on public.product_recipe_items;
create trigger product_recipe_items_set_updated_at
before update on public.product_recipe_items
for each row execute function public.set_updated_at();

drop trigger if exists ingredient_purchases_set_updated_at on public.ingredient_purchases;
create trigger ingredient_purchases_set_updated_at
before update on public.ingredient_purchases
for each row execute function public.set_updated_at();

drop trigger if exists orders_set_updated_at on public.orders;
create trigger orders_set_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

drop trigger if exists order_items_set_updated_at on public.order_items;
create trigger order_items_set_updated_at
before update on public.order_items
for each row execute function public.set_updated_at();

drop trigger if exists sales_set_updated_at on public.sales;
create trigger sales_set_updated_at
before update on public.sales
for each row execute function public.set_updated_at();

drop trigger if exists sale_items_set_updated_at on public.sale_items;
create trigger sale_items_set_updated_at
before update on public.sale_items
for each row execute function public.set_updated_at();

drop trigger if exists cash_sessions_set_updated_at on public.cash_sessions;
create trigger cash_sessions_set_updated_at
before update on public.cash_sessions
for each row execute function public.set_updated_at();

drop trigger if exists cash_movements_set_updated_at on public.cash_movements;
create trigger cash_movements_set_updated_at
before update on public.cash_movements
for each row execute function public.set_updated_at();

drop trigger if exists app_assets_set_updated_at on public.app_assets;
create trigger app_assets_set_updated_at
before update on public.app_assets
for each row execute function public.set_updated_at();

drop trigger if exists sync_queue_set_updated_at on public.sync_queue;
create trigger sync_queue_set_updated_at
before update on public.sync_queue
for each row execute function public.set_updated_at();

insert into public.settings (business_name, admin_pin, admin_mode_enabled)
select 'BJ Burguers', '1234', false
where not exists (select 1 from public.settings);
