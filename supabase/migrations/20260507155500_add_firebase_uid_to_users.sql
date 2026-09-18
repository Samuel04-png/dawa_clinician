alter table public."user"
add column if not exists firebase_uid text;

create index if not exists idx_user_firebase_uid on public."user" (firebase_uid);
