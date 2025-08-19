#!/bin/bash
cd "$(dirname "$0")"
set -xe
docker compose build --pull
docker compose pull
docker compose up -d
docker system prune -f
