#!/bin/bash
set -e
cd "$(dirname "$0")"

LIST_NAME="${1,,}"
DOMAIN_NAME="${2,,}"

if [[ -z "$LIST_NAME" || -z "$DOMAIN_NAME" ]]; then
        echo "Missing arguments, usage: $0 listname domain"
        exit 1
fi

rm -rf core/list-import web/import.mbox
trap "rm -rf core/list-import web/import.mbox" EXIT

set -x

cp -r "/var/lib/mailman/lists/${LIST_NAME,,}" core/list-import
cp "/var/lib/mailman/archives/private/${LIST_NAME,,}.mbox/${LIST_NAME,,}.mbox" web/import.mbox

chmod a+rx core/list-import
chmod a+r web/import.mbox core/list-import/*

docker compose exec -T -u mailman core /entrypoint.sh mailman create "${LIST_NAME}@${DOMAIN_NAME}"
docker compose exec -T -u mailman core /entrypoint.sh mailman import21 "${LIST_NAME}@${DOMAIN_NAME}" /opt/mailman/list-import/config.pck
docker compose exec -T -u mailman web /entrypoint.sh mailman-web hyperkitty_import -l "${LIST_NAME}@${DOMAIN_NAME}" /opt/mailman-web/import.mbox
docker compose exec -T -u mailman web /entrypoint.sh mailman-web update_index_one_list "${LIST_NAME}@${DOMAIN_NAME}"
