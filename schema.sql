-- Темп: таблица книг и хранилище файлов.
-- Выполните целиком в Supabase → SQL Editor → New query → Run.

-- 1. Книги и прогресс чтения. Каждая строка принадлежит одному пользователю.
create table if not exists public.books (
  id          text        not null,
  user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  title       text        not null,
  author      text        not null default '',
  total       integer     not null default 0,   -- слов в книге
  pos         integer     not null default 0,   -- номер слова, на котором остановились
  finished    boolean     not null default false,
  added       bigint      not null default 0,   -- время добавления, мс
  opened      bigint      not null default 0,   -- время последнего открытия, мс
  updated_ms  bigint      not null default 0,   -- время последнего изменения прогресса, мс
  primary key (user_id, id)
);

-- 2. Защита: пользователь видит и меняет только свои строки.
alter table public.books enable row level security;

drop policy if exists "books: own rows" on public.books;
create policy "books: own rows" on public.books
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 3. Приватная корзина для текстов книг. Путь файла: <id пользователя>/<id книги>.txt
insert into storage.buckets (id, name, public, file_size_limit)
values ('books', 'books', false, 52428800)
on conflict (id) do nothing;

drop policy if exists "books files: read own"   on storage.objects;
drop policy if exists "books files: insert own" on storage.objects;
drop policy if exists "books files: update own" on storage.objects;
drop policy if exists "books files: delete own" on storage.objects;

create policy "books files: read own" on storage.objects
  for select to authenticated
  using (bucket_id = 'books' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "books files: insert own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'books' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "books files: update own" on storage.objects
  for update to authenticated
  using (bucket_id = 'books' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "books files: delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'books' and (storage.foldername(name))[1] = auth.uid()::text);
