# Blog operations

The supported product is a moderated multi-author publication. Authors draft and revise; a different editor must approve and publish. Public readers only see published records. Every editorial transition, import, export, login, and media operation is attributable in `audit_events`.

Copy `.env.example` to a secret-managed environment. Production refuses to start without the database, host, and cookie-signing secret. `bin/start` never creates a database, seeds data, resets data, or kills another process. Set `RUN_MIGRATIONS=true` only in the single release job that owns migrations.

For the first administrator only, run `bin/rails db:seed` once with all three `BOOTSTRAP_ADMIN_EMAIL`, `BOOTSTRAP_ADMIN_USERNAME`, and `BOOTSTRAP_ADMIN_PASSWORD` values supplied through the secret manager. Remove them immediately afterward. Normal startup never invokes seeds.

Back up the PostgreSQL database and `MEDIA_ROOT` together. Test restore regularly. An administrator can download a portable JSON archive from `/export` and restore it through `/import`; that archive supplements, but does not replace, physical database backups.

The backup job should run `pg_dump --format=custom --no-owner` using a
read-only backup credential, archive the matching media tree, encrypt both
artifacts, and record checksums and retention metadata. A restore drill must use
an isolated database and media directory, run `pg_restore --clean --if-exists`,
start the exact release image, and verify a published article, its media,
revision history, and audit evidence. Never point a restore drill at production.

Deploy the immutable container behind TLS. Use `/articles` as the availability probe. Logs carry Rails request IDs; audit events are the business evidence stream. Alert on repeated 429/403 responses, failed migrations, database saturation, and a growing moderation queue.

Media is restricted to JPEG, PNG, and WebP, checked by signature, capped at 5 MiB, stored outside the public tree, and requires alternative text. A production object-store adapter can replace `Publishing::MediaStore` without weakening validation.
