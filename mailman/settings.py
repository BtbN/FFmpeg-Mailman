# Mailman Web configuration file.

import os
from socket import gethostbyname

from mailman_web.settings.base import *
from mailman_web.settings.mailman import *

DEBUG = False

SITE_ID = 1
FILTER_VHOST = True

STATIC_ROOT = '/opt/mailman-web/static'
STATIC_URL = '/static/'
COMPRESS_ENABLED = True

# Make sure that this directory is created or Django will fail on start.
LOGGING['handlers']['file']['filename'] = '/opt/mailman-web/logs/mailmanweb.log'

USE_X_FORWARDED_HOST = True

HAYSTACK_CONNECTIONS = {
    'default': {
        'PATH': '/opt/mailman-web/xapian_index',
        'ENGINE': 'xapian_backend.XapianEngine'
    },
}

XAPIAN_LONG_TERM_METHOD = 'hash'

EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'host.docker.internal'
EMAIL_PORT = 25
EMAIL_USE_TLS = False
EMAIL_USE_SSL = False

# Deprecated but set by defaults
ACCOUNT_AUTHENTICATION_METHOD = ACCOUNT_EMAIL_REQUIRED = None
del ACCOUNT_AUTHENTICATION_METHOD
del ACCOUNT_EMAIL_REQUIRED

ACCOUNT_LOGIN_METHODS = {'email', 'username'}
ACCOUNT_SIGNUP_FIELDS = ['username*', 'email*', 'password1*', 'password2*']
ACCOUNT_EMAIL_VERIFICATION = 'mandatory'
ACCOUNT_DEFAULT_HTTP_PROTOCOL = 'https'
ACCOUNT_UNIQUE_EMAIL  = True

DISKCACHE_PATH = '/opt/mailman-web/diskcache'
DISKCACHE_SIZE = 1024 * 1024 * 1024

MAILMAN_REST_API_URL = 'http://core:8001'
MAILMAN_ARCHIVER_FROM = (gethostbyname('core'),'core')

ALLOWED_HOSTS = []
CSRF_TRUSTED_ORIGINS = []

from settings_docker import *

ALLOWED_HOSTS.extend([
    'web',
    'localhost',
    '127.0.0.1'
])

CACHES = {
    'default': {
        'BACKEND': 'diskcache.DjangoCache',
        'LOCATION': DISKCACHE_PATH,
        'OPTIONS': {
            'size_limit': DISKCACHE_SIZE,
        },
    },
}
