#!/bin/bash
set -e
cd "$(dirname "$0")"
source .env

rm -rf backup
trap "rm -rf backup" EXIT
mkdir backup

docker compose exec -T db mariadb-dump --opt --single-transaction --extended-insert --user="$DATABASE_USER_CORE" --password="$DATABASE_PASS_CORE" --databases "$DATABASE_NAME_CORE" | gzip > backup/core.sql.gz
docker compose exec -T db mariadb-dump --opt --single-transaction --extended-insert --user="$DATABASE_USER_WEB" --password="$DATABASE_PASS_WEB" --databases "$DATABASE_NAME_WEB" | gzip > backup/web.sql.gz

cp -a core backup/core
cp -a web backup/web

tar czf backup.tar.gz backup
