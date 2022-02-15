FROM debian:stretch
MAINTAINER "cytopia" <cytopia@everythingcli.org>

# persistent / runtime deps
RUN set -eux \
	&& DEBIAN_FRONTEND=noninteractive apt-get update -qq \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --no-install-recommends --no-install-suggests \
		ca-certificates \
		curl \
		libpcre3 \
		librecode0 \
		libmariadbclient-dev-compat \
		libsqlite3-0 \
		libxml2 \
	&& DEBIAN_FRONTEND=noninteractive apt-get purge -qq -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
	&& rm -rf /var/lib/apt/lists/*

# phpize deps
RUN set -eux \
	&& DEBIAN_FRONTEND=noninteractive apt-get update -qq \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --no-install-recommends --no-install-suggests \
		autoconf \
		file \
		dpkg-dev \
		g++ \
		gcc \
		libc-dev \
		make \
		pkg-config \
		re2c \
		xz-utils \
	&& if [ "$(dpkg-architecture --query DEB_HOST_ARCH)" = "i386" ]; then \
		DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --no-install-recommends --no-install-suggests \
			g++-multilib \
			gcc-multilib; \
	fi \
	&& DEBIAN_FRONTEND=noninteractive apt-get purge -qq -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
	&& rm -rf /var/lib/apt/lists/*

ENV PHP_INI_DIR /usr/local/etc/php
RUN mkdir -p $PHP_INI_DIR/conf.d

# compile openssl, otherwise --with-openssl won't work
RUN set -eux \
	&& OPENSSL_VERSION="1.0.1t" \
	&& cd /tmp \
	&& mkdir openssl \
	&& update-ca-certificates \
	&& curl -sS -k -L --fail "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz \
	&& curl -sS -k -L --fail "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz.asc" -o openssl.tar.gz.asc \
	&& tar -xzf openssl.tar.gz -C openssl --strip-components=1 \
	&& cd /tmp/openssl \
	&& if [ "$(dpkg-architecture  --query DEB_HOST_ARCH)" = "i386" ]; then \
		setarch i386 ./config -m32; \
	else \
		./config; \
	fi \
	&& make depend \
	&& make -j"$(nproc)" \
	&& make install \
	&& rm -rf /tmp/*

ENV PHP_VERSION 5.3.29
COPY data/docker-php-source /usr/local/bin/

# php 5.3 needs older autoconf
# --enable-mysqlnd is included below because it's harder to compile after the fact the extensions are (since it's a plugin for several extensions, not an extension in itself)
RUN set -eux \
	&& buildDeps=" \
		autoconf2.13 \
		libcurl4-openssl-dev \
		libpcre3-dev \
		libreadline6-dev \
		librecode-dev \
		libsqlite3-dev \
		libssl-dev \
		libxml2-dev \
	" \
	&& DEBIAN_FRONTEND=noninteractive apt-get update -qq \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -qq -y --no-install-recommends --no-install-suggests \
		${buildDeps} \
	&& DEBIAN_FRONTEND=noninteractive apt-get purge -qq -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
	&& rm -rf /var/lib/apt/lists/* \
	\
	&& mkdir -p /usr/src/php \
	&& curl -sS -k -L --fail "http://php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror" -o /usr/src/php.tar.xz \
	&& curl -sS -k -L --fail "http://php.net/get/php-$PHP_VERSION.tar.xz.asc/from/this/mirror" -o /usr/src/php.tar.xz.asc \
	&& docker-php-source extract \
	&& cd /usr/src/php  \
	\
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)" \
	\
	# Fix libmariadbclient lib location
	&& find /usr/lib/ -name '*mariadbclient*' | xargs -n1 sh -c 'ln -s "${1}" "/usr/lib/$( basename "${1}" | sed "s|libmariadbclient|libmysqlclient|g" )"' -- \
	\
	# https://bugs.php.net/bug.php?id=74125
	&& if [ ! -d /usr/include/curl ]; then \
		ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
	fi \
	\
	&& ./configure \
		--host="${gnuArch}" \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		--enable-fpm \
		--with-fpm-user=www-data \
		--with-fpm-group=www-data \
		--disable-cgi \
		--enable-mysqlnd \
		--with-mysql \
		--with-curl \
		--with-openssl=/usr/local/ssl \
		--with-readline \
		--with-recode \
		--with-zlib \
	&& make -j"$(nproc)" \
	&& make install \
	&& make clean \
	\
	&& { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } \
	\
	&& cd / \
	&& docker-php-source delete \
	\
	&& DEBIAN_FRONTEND=noninteractive apt-get purge -qq -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false ${buildDeps} \
	&& rm -rf /var/lib/apt/lists/*

COPY data/docker-php-* /usr/local/bin/

WORKDIR /var/www/html
COPY data/php-fpm.conf /usr/local/etc/

EXPOSE 9000
CMD ["php-fpm"]
