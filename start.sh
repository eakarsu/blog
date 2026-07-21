#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$project_dir"

if [[ -d /opt/homebrew/opt/ruby/bin ]]; then
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
fi

# Runtime acceptance uses an isolated SQLite copy. Never prepare, replace, or
# seed the checked-in development/test databases during normal startup.
if [[ "${NODE_ENV:-}" == "test" && -n "${DB_PATH:-}" ]]; then
  case "$DB_PATH" in
    /*) ;;
    *) echo "DB_PATH must be absolute in test mode" >&2; exit 1 ;;
  esac
  export RAILS_ENV=test TEST_DATABASE_PATH="$DB_PATH"
  unset DATABASE_URL
  if [[ ! -e "$DB_PATH" ]]; then
    install -m 600 db/test.sqlite3 "$DB_PATH"
  elif [[ ! -s "$DB_PATH" ]]; then
    echo "Refusing to replace empty test database: $DB_PATH" >&2
    exit 1
  fi

  if [[ -n "${ADMIN_EMAIL:-}" && -n "${ADMIN_PASSWORD:-}" ]]; then
    bundle exec rails runner '
      user = User.find_or_initialize_by(email: ENV.fetch("ADMIN_EMAIL").downcase.strip)
      user.assign_attributes(
        username: "runtime_admin",
        password: ENV.fetch("ADMIN_PASSWORD"),
        role: "administrator",
        active: true
      )
      user.save!
    '
  fi
fi

exec ./bin/start
