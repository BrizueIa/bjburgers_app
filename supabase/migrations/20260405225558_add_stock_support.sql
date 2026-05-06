create table if not exists public.spin_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  remaining_spins integer not null default 0,
  is_active boolean not null default true,
  sale_id uuid references public.sales(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (code)
);

create index if not exists spin_codes_code_idx
  on public.spin_codes using btree (code);

drop trigger if exists spin_codes_set_updated_at on public.spin_codes;
create trigger spin_codes_set_updated_at
before update on public.spin_codes
for each row execute function public.set_updated_at();
