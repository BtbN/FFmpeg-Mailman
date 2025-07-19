#!/bin/bash
set -eo pipefail

setup_core() {
    cat /etc/mailman.cfg.proto > /etc/mailman.cfg
    cat /etc/mailman-hyperkitty.cfg.proto > /etc/mailman-hyperkitty.cfg

    if [[ -n "$DATABASE_USER" && -n "$DATABASE_PASS" && -n "$DATABASE_NAME" ]]; then
        DATABASE_SERV="${DATABASE_SERV:-db}"
        DATABASE_EXTRA_ARGS="${DATABASE_EXTRA_ARGS:-}"
        {
            echo "[database]"
            echo "class: mailman.database.mysql.MySQLDatabase"
            echo "url: mysql+mysqldb://${DATABASE_USER}:${DATABASE_PASS}@${DATABASE_SERV}:3306/${DATABASE_NAME}?charset=utf8mb4&use_unicode=1${DATABASE_EXTRA_ARGS}"
            echo
        } >> /etc/mailman.cfg
    else
        echo "Missing database credentials"
        exit 1
    fi

    if [[ -n "$REST_ADMIN_USER" && -n "$REST_ADMIN_PASS" ]]; then
        {
            echo "[webservice]"
            echo "admin_user: ${REST_ADMIN_USER}"
            echo "admin_pass: ${REST_ADMIN_PASS}"
            echo
        } >> /etc/mailman.cfg
    else
        echo "Missing rest admin credentials"
        exit 1
    fi

    if [[ -n "$SITE_OWNER" ]]; then
        {
            echo "[mailman]"
            echo "site_owner: ${SITE_OWNER}"
            echo
        } >> /etc/mailman.cfg
    else
        echo "Missing site-owner"
        exit 1
    fi

    if [[ -n "$HYPERKITTY_API_KEY" ]]; then
        {
            echo "[general]"
            echo "api_key: ${HYPERKITTY_API_KEY}"
            echo
        } >> /etc/mailman-hyperkitty.cfg
    else
        echo "Missing site-owner"
        exit 1
    fi

    if [[ -n "$LMTP_HOST" || -n "$LMTP_PORT" || -n "$SMTP_HOST" || -n "$SMTP_PORT" || -n "$SMTP_USER" || -n "$SMTP_PASS" || -n "$SMTP_SECURE_MODE" || -n "$SMTP_VERIFY_HOSTNAME" || -n "$SMTP_VERIFY_CERT" ]]; then
        {
            echo "[mta]"
            [[ -z "$LMTP_HOST" ]] || echo "lmtp_host: ${LMTP_HOST}"
            [[ -z "$LMTP_PORT" ]] || echo "lmtp_port: ${LMTP_PORT}"
            [[ -z "$SMTP_HOST" ]] || echo "smtp_host: ${SMTP_HOST}"
            [[ -z "$SMTP_PORT" ]] || echo "smtp_port: ${SMTP_PORT}"
            [[ -z "$SMTP_USER" ]] || echo "smtp_user: ${SMTP_USER}"
            [[ -z "$SMTP_PASS" ]] || echo "smtp_pass: ${SMTP_PASS}"
            [[ -z "$SMTP_SECURE_MODE" ]] || echo "smtp_secure_mode: ${SMTP_SECURE_MODE}"
            [[ -z "$SMTP_VERIFY_HOSTNAME" ]] || echo "smtp_verify_hostname: ${SMTP_VERIFY_HOSTNAME}"
            [[ -z "$SMTP_VERIFY_CERT" ]] || echo "smtp_verify_cert: ${SMTP_VERIFY_CERT}"
            echo
        } >> /etc/mailman.cfg
    fi

    chown -R mailman:mailman /opt/mailman

    cd /opt/mailman
    export MAILMAN_CONFIG_FILE=/etc/mailman.cfg
    
    sudo -n -u mailman -- mailman aliases
}

run_core() {
    cd /opt/mailman
    export MAILMAN_CONFIG_FILE=/etc/mailman.cfg
    exec sudo -n -u mailman -- master --force "$@"
}

setup_web() {
    true
}

run_web() {
    cd /opt/mailman-web
    exec sudo -n -u mailman -- uwsgi --init /etc/uwsgi.ini "$@"
}

if [[ "$1" == "core" ]]; then
    shift
    setup_core
    run_core "$@"
elif [[ "$1" == "web" ]]; then
    shift
    setup_web
    run_web "$@"
else
    exec sudo -n -u mailman -- "$@"
fi
