#!/bin/bash
set -e
cd "$(dirname "$0")"

LIST_NAME="${1,,}"
DOMAIN_NAME="${2,,}"

if [[ -z "$LIST_NAME" || -z "$DOMAIN_NAME" ]]; then
        echo "Missing arguments, usage: $0 listname domain"
        exit 1
fi

rm -rf core/list-import web/import.mbox public-inbox/import.mbox
trap "rm -rf core/list-import web/import.mbox public-inbox/import.mbox" EXIT

set -x

cp -r "/var/lib/mailman/lists/${LIST_NAME,,}" core/list-import
chmod -R a+rX core/list-import

ARCHIVE_MBOX="/var/lib/mailman/archives/private/${LIST_NAME,,}.mbox/${LIST_NAME,,}.mbox"
if [[ -f "$ARCHIVE_MBOX" ]]; then
    cp -l "$ARCHIVE_MBOX" web/import.mbox
    cp -l "$ARCHIVE_MBOX" public-inbox/import.mbox
    chmod a+r web/import.mbox public-inbox/import.mbox
fi

docker compose exec -T core /entrypoint.sh mailman create "${LIST_NAME}@${DOMAIN_NAME}"
docker compose exec -T core /entrypoint.sh mailman import21 "${LIST_NAME}@${DOMAIN_NAME}" /opt/mailman/list-import/config.pck

if [[ -f "$ARCHIVE_MBOX" ]]; then
    docker compose exec -T web /entrypoint.sh mailman-web hyperkitty_import -l "${LIST_NAME}@${DOMAIN_NAME}" /opt/mailman-web/import.mbox
    docker compose exec -T public-inbox /entrypoint.sh public-inbox-init -V2 "${LIST_NAME}" /opt/public-inbox/"${LIST_NAME}" "https://lists.${DOMAIN_NAME}/lore/${LIST_NAME}/" "${LIST_NAME}@${DOMAIN_NAME}"
    docker compose exec -T public-inbox /entrypoint.sh lei convert -o v2:/opt/public-inbox/"${LIST_NAME}" mboxo:/opt/public-inbox/import.mbox
    docker compose exec -T web /entrypoint.sh mailman-web update_index_one_list "${LIST_NAME}@${DOMAIN_NAME}"
fi
