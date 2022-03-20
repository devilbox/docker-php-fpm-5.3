#!/usr/bin/env bash
set -eu
set -o pipefail

IMAGE="${1}"
#NAME="${2}"
VERSION="${3}"
TAG="${4}"
ARCH="${5}"


DOC_ROOT_HOST="$( mktemp -d )"
DOC_ROOT_CONT="/var/www/default"

# PHP scripts
{
	echo '<?php'
	echo 'error_reporting("E_ALL & ~E_NOTICE & ~E_WARNING");'
	echo 'echo "[PHP] Calling imap_open() with SSL support";'
	echo 'imap_open("{outlook.office365.com:993/service=imap/ssl}", "demo", "123456");'
} > "${DOC_ROOT_HOST}/imap-01.php"

# Run screipt
{
	echo '#!/usr/bin/env bash'
	echo
	echo 'set -eux'
	echo 'set -o pipefail'
	echo
	echo 'apt update'
	echo "apt install -y \\
			autoconf \\
			ca-certificates \\
			curl \\
			dpkg-dev \\
			file \\
			flex \\
			g++ \\
			gcc \\
			libc-client-dev \\
			libc-dev \\
			libcurl4-openssl-dev \\
			libkrb5-dev \\
			libssl-dev \\
			make \\
			patch \\
			pkg-config \\
			re2c \\
			xz-utils"
	echo 'ln -s /usr/lib/$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)/libkrb5* /usr/lib/'
	echo 'docker-php-ext-configure imap --with-kerberos --with-imap-ssl --with-imap'
	echo 'docker-php-ext-install imap'
	echo
	echo "# Check PHP errors"
	echo 'PHP_ERROR="$( php -v 2>&1 1>/dev/null )"'
	echo 'if [ -n "${PHP_ERROR}" ]; then echo "${PHP_ERROR}"; exit 1; fi'
	echo 'PHP_ERROR="$( php -i 2>&1 1>/dev/null )"'
	echo 'if [ -n "${PHP_ERROR}" ]; then echo "${PHP_ERROR}"; exit 1; fi'
	echo
	echo "# Check PHP-FPM errors"
	echo 'PHP_FPM_ERROR="$( php-fpm -v 2>&1 1>/dev/null )"'
	echo 'if [ -n "${PHP_FPM_ERROR}" ]; then echo "${PHP_FPM_ERROR}"; exit 1; fi'
	echo 'PHP_FPM_ERROR="$( php-fpm -i 2>&1 1>/dev/null )"'
	echo 'if [ -n "${PHP_FPM_ERROR}" ]; then echo "${PHP_FPM_ERROR}"; exit 1; fi'
	echo
	echo "# Check imap module"
	echo "php -m | grep '^imap\$'"
	echo "php-fpm -m | grep '^imap\$'"
	echo
	echo
	echo "# In case it succeeds, check for PHP errors in output."
	echo "if php ${DOC_ROOT_CONT}/imap-01.php; then"
	echo "    if php ${DOC_ROOT_CONT}/imap-01.php 2>&1 | grep -Ei 'error|fatal|segfault|core|dump'; then"
	echo "        exit 1"
	echo "    fi"
	echo "fi"

} > "${DOC_ROOT_HOST}/run.sh"
chmod +x "${DOC_ROOT_HOST}/run.sh"


echo
docker run \
	--rm \
	--platform "${ARCH}" \
	-v "${DOC_ROOT_HOST}:${DOC_ROOT_CONT}" \
	"${IMAGE}:${TAG}" bash -c "cat ${DOC_ROOT_CONT}/run.sh && ${DOC_ROOT_CONT}/run.sh"
