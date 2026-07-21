# Blog

Blog is a moderated multi-author publishing application. It supports private drafts, immutable revision evidence, categories and tags, independent editorial review, publication timestamps, archives, governed comment moderation, media validation, public search, Atom feeds, SEO metadata, portable export/import, and attributable audit events.

## Local development

Use Ruby 3.4. Copy `.env.example` into your secret manager or shell, then run:

```sh
bundle install
bin/rails db:prepare
bin/start
```

`bin/start` is intentionally non-destructive. It will not create, reset, seed, or migrate a database unless `RUN_MIGRATIONS=true` is explicitly set. Production additionally requires `DATABASE_URL`, `SECRET_KEY_BASE`, and `APP_HOST`.

Run `bin/rails test`, `bin/rails zeitwerk:check`, `brakeman`, and `bundler-audit check` before release. See `OPERATIONS.md` for deployment, backup, restore, media, and observability details.

## Roles and workflow

- Authors own drafts and may submit them for review.
- Editors may request changes, approve, and publish work they did not author.
- Administrators additionally manage people, taxonomies, imports, and exports.
- Public readers can search, read, and subscribe only to published content.

Editorial transitions use optimistic locking and generate both a content digest revision and an audit event. Uploaded media is signature checked, size limited, non-public by default, and requires alt text.
