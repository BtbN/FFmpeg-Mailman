#!/bin/bash
set -eo pipefail

ensure_mysql() {
    if [[ -z "$DATABASE_USER" || -z "$DATABASE_PASS" || -z "$DATABASE_NAME" ]]; then
        echo "Missing database credentials"
        return
    fi

    DATABASE_SERV="${DATABASE_SERV:-db}"
    DATABASE_PORT="${DATABASE_PORT:-3306}"

    until python3 -c "import MySQLdb; MySQLdb.connect(host='${DATABASE_SERV}', port=${DATABASE_PORT}, user='${DATABASE_USER}', passwd='${DATABASE_PASS}', connect_timeout=1).cursor().execute('SELECT 1')"; do
        echo "Waiting for mysql server..."
        sleep 1
    done
}

setup_core() {
    cp /etc/mailman3/mailman.cfg{.proto,}
    cp /etc/mailman3/mailman-hyperkitty.cfg{.proto,}
    cp /etc/mailman3/mailman-public-inbox.cfg{.proto,}

    if [[ -n "$DATABASE_USER" && -n "$DATABASE_PASS" && -n "$DATABASE_NAME" ]]; then
        {
            DATABASE_SERV="${DATABASE_SERV:-db}"
            DATABASE_PORT="${DATABASE_PORT:-3306}"
            echo "[database]"
            echo "class: mailman.database.mysql.MySQLDatabase"
            echo "url: mysql+mysqldb://${DATABASE_USER}:${DATABASE_PASS}@${DATABASE_SERV}:${DATABASE_PORT}/${DATABASE_NAME}?charset=utf8mb4&use_unicode=1"
            echo
        } >> /etc/mailman3/mailman.cfg
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
        } >> /etc/mailman3/mailman.cfg
    else
        echo "Missing rest admin credentials"
        exit 1
    fi

    if [[ -n "$SITE_OWNER" ]]; then
        {
            echo "[mailman]"
            echo "site_owner: ${SITE_OWNER}"
            echo
        } >> /etc/mailman3/mailman.cfg
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
        } >> /etc/mailman3/mailman.cfg
    fi

    if [[ -n "$HYPERKITTY_API_KEY" ]]; then
        {
            echo "api_key: ${HYPERKITTY_API_KEY}"
            echo
        } >> /etc/mailman3/mailman-hyperkitty.cfg
    else
        echo "Missing site-owner"
        exit 1
    fi

    if [[ -n "$PUBLIC_INBOX_HOST" ]]; then
        {
            echo "base_url: ${PUBLIC_INBOX_HOST}"
            echo
        } >> /etc/mailman3/mailman-public-inbox.cfg
    else
        echo "Missing public-inbox host"
        exit 1
    fi

    chown -R mailman:mailman /opt/mailman

    cd /opt/mailman
    export MAILMAN_CONFIG_FILE=/etc/mailman3/mailman.cfg

    sudo -n -u mailman -- mailman aliases
}

setup_web() {
    rm -f /etc/mailman3/settings_docker.py

    if [[ -n "$SMTP_HOST" || -n "$SMTP_PORT" || -n "$SMTP_USER" || -n "$SMTP_PASS" || -n "$SMTP_USE_TLS" || -n "$SMTP_USE_SSL" ]]; then
        {
            [[ -z "$SMTP_HOST" ]] || echo "EMAIL_HOST = ${SMTP_HOST}"
            [[ -z "$SMTP_PORT" ]] || echo "EMAIL_PORT = ${SMTP_PORT}"
            [[ -z "$SMTP_USER" ]] || echo "EMAIL_HOST_USER = ${SMTP_USER}"
            [[ -z "$SMTP_PASS" ]] || echo "EMAIL_HOST_PASSWORD = ${SMTP_PASS}"
            [[ -z "$SMTP_USE_TLS" ]] || echo "EMAIL_USE_TLS = ${SMTP_USE_TLS}"
            [[ -z "$SMTP_USE_SSL" ]] || echo "EMAIL_USE_SSL = ${SMTP_USE_SSL}"
            echo
        } >> /etc/mailman3/settings_docker.py
    fi

    if [[ -n "$DATABASE_USER" && -n "$DATABASE_PASS" && -n "$DATABASE_NAME" ]]; then
        {
            DATABASE_SERV="${DATABASE_SERV:-db}"
            DATABASE_PORT="${DATABASE_PORT:-3306}"
            echo "DATABASES = {"
            echo "    'default': {"
            echo "        'ENGINE': 'django.db.backends.mysql',"
            echo "        'NAME': '${DATABASE_NAME}',"
            echo "        'USER': '${DATABASE_USER}',"
            echo "        'PASSWORD': '${DATABASE_PASS}',"
            echo "        'HOST': '${DATABASE_SERV}',"
            echo "        'PORT': '${DATABASE_PORT}',"
            echo "        'OPTIONS': {'charset': 'utf8mb4'}"
            echo "    }"
            echo "}"
            echo
        } >> /etc/mailman3/settings_docker.py
    else
        echo "Missing database credentials"
        exit 1
    fi

    if [[ -n "$SECRET_KEY" ]]; then
        {
            echo "SECRET_KEY = '${SECRET_KEY}'"
            echo
        } >> /etc/mailman3/settings_docker.py
    else
        echo "Missing django's secret key"
        exit 1
    fi

    if [[ -n "$HYPERKITTY_API_KEY" ]]; then
        {
            echo "MAILMAN_ARCHIVER_KEY = '${HYPERKITTY_API_KEY}'"
            echo
        } >> /etc/mailman3/settings_docker.py
    else
        echo "Missing hyperkitty API key"
        exit 1
    fi

    if [[ -n "$REST_ADMIN_USER" && -n "$REST_ADMIN_PASS" ]]; then
        {
            echo "MAILMAN_REST_API_USER = '${REST_ADMIN_USER}'"
            echo "MAILMAN_REST_API_PASS = '${REST_ADMIN_PASS}'"
            echo
        } >> /etc/mailman3/settings_docker.py
    else
        echo "Missing rest admin credentials"
        exit 1
    fi

    if [[ -n "$DEFAULT_FROM_EMAIL" && -n "$SERVER_EMAIL" ]]; then
        {
            echo "DEFAULT_FROM_EMAIL = '${DEFAULT_FROM_EMAIL}'"
            echo "SERVER_EMAIL = '${SERVER_EMAIL}'"
            echo
        } >> /etc/mailman3/settings_docker.py
    else
        echo "Missing server e-mail addresses"
        exit 1
    fi

    if [[ -n "$SERVE_FROM_DOMAINS" ]]; then
        {
            IFS=', ' read -ra DOMAINS <<< "$SERVE_FROM_DOMAINS"

            echo "ALLOWED_HOSTS = ["
            for DOMAIN in "${DOMAINS[@]}"; do
                echo "    '${DOMAIN}',"
            done
            echo "]"

            echo "CSRF_TRUSTED_ORIGINS = ["
            for DOMAIN in "${DOMAINS[@]}"; do
                echo "    'https://${DOMAIN}',"
            done
            echo "]"

            echo
        } >> /etc/mailman3/settings_docker.py
    else
        echo "No domains configured"
        exit 1
    fi

    cd /opt/mailman-web
    mkdir -p logs static diskcache xapian_index
    chown -R mailman:mailman /opt/mailman-web

    export MAILMAN_WEB_CONFIG=/etc/mailman3/settings.py

    pushd /usr/local/lib/python?.*/site-packages
    mailman-web compilemessages
    popd

    sudo -n -u mailman -- mailman-web migrate

    sudo -n -u mailman -- mailman-web collectstatic --noinput --clear
    sudo -n -u mailman -- mailman-web compress --force

    echo "SITE_ID = 0" >> /etc/mailman3/settings_docker.py
}

setup_pihttpd() {
    chown -R mailman:mailman /opt/public-inbox
    cp /etc/mailman3/pi.psgi{.proto,}

    if [[ -n "$PUBLIC_INBOX_WEBMOUNT" ]]; then
        sed -i -e "s|@@@MOUNTPOINT@@@|${PUBLIC_INBOX_WEBMOUNT}|g" /etc/mailman3/pi.psgi
    else
        echo "Mounting public-inbox at /"
        sed -i -e "s|@@@MOUNTPOINT@@@|/|g" /etc/mailman3/pi.psgi
    fi
}

run_core() {
    cd /opt/mailman
    export MAILMAN_CONFIG_FILE=/etc/mailman3/mailman.cfg
    exec sudo -n --preserve-env=MAILMAN_CONFIG_FILE -u mailman -- master --force "$@"
}

run_web() {
    cd /opt/mailman-web
    export MAILMAN_WEB_CONFIG=/etc/mailman3/settings.py
    exec sudo -n --preserve-env=MAILMAN_WEB_CONFIG -u mailman -- uwsgi --ini /etc/mailman3/uwsgi.ini "$@"
}

init_pihttpd_reloader() {
    (
        echo "Monitoring for pihttpd config changes"

        while [[ ! -e /opt/public-inbox/.public-inbox ]]; do
            sleep 60
        done

        inotifywait -m -q --format '%e %f' -e moved_to -e close_write /opt/public-inbox/.public-inbox |
        while read -r events file; do
            if [[ "$file" == "config" ]]; then
                echo "Reloading pihttpd"
                pkill -f -HUP public-inbox-httpd
            fi
        done
    ) &
}

run_pihttpd() {
    cd /opt/public-inbox
    export PERL_INLINE_DIRECTORY=/var/cache/pi-inline-c
    export PI_CONFIG=/opt/public-inbox/.public-inbox/config
    export PI_DIR=/opt/public-inbox/.public-inbox
    export HOME=/opt/public-inbox
    exec sudo -n --preserve-env=PERL_INLINE_DIRECTORY,PI_CONFIG,PI_DIR,HOME -u mailman -- public-inbox-httpd -l http://0.0.0.0:8080 -W4 -X4 "$@" /etc/mailman3/pi.psgi
}

if [[ "$1" == "core" ]]; then
    shift
    ensure_mysql
    setup_core
    run_core "$@"
elif [[ "$1" == "web" ]]; then
    shift
    ensure_mysql
    setup_web
    run_web "$@"
elif [[ "$1" == "pihttpd" ]]; then
    shift
    setup_pihttpd
    init_pihttpd_reloader
    run_pihttpd "$@"
elif [[ "$1" == "logrotate" ]]; then
    shift
    exec sudo -n -u mailman -- /logrotate.sh "$@"
else
    export MAILMAN_CONFIG_FILE=/etc/mailman3/mailman.cfg
    export MAILMAN_WEB_CONFIG=/etc/mailman3/settings.py
    export PI_CONFIG=/opt/public-inbox/.public-inbox/config
    export PI_DIR=/opt/public-inbox/.public-inbox
    exec sudo -n --preserve-env=MAILMAN_CONFIG_FILE,MAILMAN_WEB_CONFIG,PI_CONFIG,PI_DIR -u mailman -- "$@"
fi
