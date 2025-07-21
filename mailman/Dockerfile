ARG PYTHON_VERSION="3.12"
FROM python:${PYTHON_VERSION}-slim AS builder

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get -y update && \
    apt-get -y full-upgrade && \
    apt-get -y install --no-install-recommends \
        curl build-essential pkgconf zlib1g-dev default-libmysqlclient-dev && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /out
WORKDIR /out

RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel build

ARG XAPIAN_VERSION="1.4.29"
RUN curl -L https://raw.githubusercontent.com/notanumber/xapian-haystack/master/xapian_wheel_builder.sh -o xapian_wheel_builder.sh && \
    sh ./xapian_wheel_builder.sh "${XAPIAN_VERSION}" && \
    rm ./xapian_wheel_builder.sh

RUN python3 -m pip wheel --no-cache-dir --no-binary :all: --use-pep517 uwsgi

RUN python3 -m pip wheel --no-cache-dir --no-binary :all: mysqlclient


FROM python:${PYTHON_VERSION}-slim

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get -y update && \
    apt-get -y full-upgrade && \
    apt-get -y install --no-install-recommends \
        sassc node-less gettext zlib1g libmariadb3 logrotate sudo nano && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

RUN --mount=from=builder,source=/out,target=/wheels \
    python3 -m pip install --no-cache-dir --use-pep517 /wheels/*.whl xapian-haystack diskcache mailman mailman-web mailman-hyperkitty

# This line will break once the next version of hyperkitty is release, which supports latest mistune.
RUN python3 -m pip show hyperkitty | grep '^Version: 1.3.12$' && python3 -m pip install 'mistune<3.1' || exit 1

ARG UID=1099
ARG GID=1099
RUN groupadd -g "${GID}" mailman && \
    useradd -g "${GID}" -u "${UID}" -s /bin/bash -m -d /home/mailman mailman

RUN mkdir /opt/mailman /opt/mailman-web && \
    chown mailman:mailman /opt/mailman /opt/mailman-web

COPY entrypoint.sh /entrypoint.sh
COPY logrotate.sh /logrotate.sh
COPY mailman.cfg mailman-postfix.cfg mailman-hyperkitty.cfg mailman-gunicorn.cfg uwsgi.ini settings.py logrotate.conf /etc/mailman3/
COPY mailman.cfg /etc/mailman3/mailman.cfg.proto
COPY mailman-hyperkitty.cfg /etc/mailman3/mailman-hyperkitty.cfg.proto

ENTRYPOINT ["/entrypoint.sh"]
