create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text not null default '',
  accent        text not null default 'green',
  avatar_url    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table public.series (
  id                uuid primary key,
  user_id           uuid not null references auth.users(id) on delete cascade,
  week_start        date not null,
  is_warmup         boolean not null default false,
  wins              int not null default 0,
  losses            int not null default 0,
  series_result     text not null default 'inProgress',
  recap_headline    text not null default '',
  recap_body        text not null default '',
  follow_up_evaluated boolean not null default false,
  follow_up_honored   boolean not null default false,
  updated_at        timestamptz not null default now(),
  unique (user_id, week_start)
);

create table public.games (
  id                  uuid primary key,
  series_id           uuid not null references public.series(id) on delete cascade,
  user_id             uuid not null references auth.users(id) on delete cascade,
  date                date not null,
  game_number         int not null,
  verdict             text not null default 'pending',
  verdict_one_liner   text not null default '',
  score_effort        double precision not null default 0,
  score_discipline    double precision not null default 0,
  score_mood          double precision not null default 0,
  score_productivity  double precision not null default 0,
  excused             boolean not null default false,
  off_season          boolean not null default false,
  challenged          boolean not null default false,
  challenge_overturned boolean not null default false,
  song_title          text not null default '',
  song_artist         text not null default '',
  updated_at          timestamptz not null default now(),
  unique (series_id, game_number)
);

create table public.settings (
  user_id                uuid primary key references auth.users(id) on delete cascade,
  accent                 text not null default 'green',
  guide                  text not null default 'king',
  theme                  text not null default 'hardwood',
  recurring_tasks        text[] not null default '{}',
  notifications_enabled  boolean not null default true,
  morning_hour           int not null default 9,
  morning_minute         int not null default 0,
  evening_hour           int not null default 20,
  evening_minute         int not null default 0,
  updated_at             timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.series   enable row level security;
alter table public.games    enable row level security;
alter table public.settings enable row level security;

create policy "own profile"  on public.profiles for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "own series"   on public.series   for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own games"    on public.games    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own settings" on public.settings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
