#
#
#

FROM arm32v6/alpine:3.8

LABEL maintainer="Nick Gregory <docker@openenterprise.co.uk>"

ARG KONG_VERSION="0.14.1"
ARG KONG_SHA256="945a90568838ffb7ee89e6816576a26aae0e860b5ff0a4c396f4299062eb0001"

ARG LUAROCKS_VERSION="2.4.4"
ARG LUAROCKS_SHA256="3938df33de33752ff2c526e604410af3dceb4b7ff06a770bc4a240de80a1f934"

ARG RESTY_VERSION="1.13.6.2"
ARG RESTY_SHA256="946e1958273032db43833982e2cec0766154a9b5cb8e67868944113208ff2942"

ARG RESTY_J="3"
ARG RESTY_CONFIG_OPTIONS="\
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --with-ipv6 \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    "
ARG RESTY_CONFIG_OPTIONS_MORE=""

LABEL resty_version="${RESTY_VERSION}"
LABEL resty_config_options="${RESTY_CONFIG_OPTIONS}"
LABEL resty_config_options_more="${RESTY_CONFIG_OPTIONS_MORE}"

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS=""

COPY patches/00ipv6_resolver.patch /tmp/00ipv6_resolver.patch
COPY patches/01ipv6_kong_dns_aaaa_support.patch /tmp/01ipv6_kong_dns_aaaa_support.patch

RUN apk add --no-cache --virtual .build-deps \
        build-base \
        git \
        curl \
        gd-dev \
        musl-dev \
        pcre-dev \
        openssl-dev \
        geoip-dev \
        libxslt-dev \
        linux-headers \
        make \
        perl-dev \
        readline-dev \
        zlib-dev \
    && apk add --no-cache \
        gd \
        geoip \
        perl \
        openssl \
        pcre \
        libgcc \
        libxslt \
        zlib \
    && cd /tmp \
    && echo "==> Downloading OpenResty..." \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && echo "${RESTY_SHA256}  openresty-${RESTY_VERSION}.tar.gz" | sha256sum -c - \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && patch -p1 < /tmp/00ipv6_resolver.patch \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && echo "==> Downloading LuaRocks..." \
    && curl -fSL https://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz -o luarocks-${LUAROCKS_VERSION}.tar.gz \
    && echo "${LUAROCKS_SHA256}  luarocks-${LUAROCKS_VERSION}.tar.gz" | sha256sum -c - \
    && tar xzf luarocks-${LUAROCKS_VERSION}.tar.gz \
    && cd /tmp/luarocks-${LUAROCKS_VERSION} \
    && ./configure --prefix=/usr/local/openresty/luajit \
        --with-lua=/usr/local/openresty/luajit \
        --lua-suffix=jit \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
    && make \
    && make install \
    && ln -s /usr/local/openresty/luajit/bin/luajit /usr/local/bin/lua \
    && export PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin \
    && cd /tmp \
    && echo "==> Downloading Kong..." \
    && curl -fSL https://github.com/Kong/kong/archive/${KONG_VERSION}.tar.gz -o kong-${KONG_VERSION}.tar.gz \
    && echo "${KONG_SHA256}  kong-${KONG_VERSION}.tar.gz" | sha256sum -c - \
    && tar xzf kong-${KONG_VERSION}.tar.gz \
    && cd /tmp/kong-${KONG_VERSION} \
    && patch -p1 < /tmp/01ipv6_kong_dns_aaaa_support.patch \
    && /usr/local/openresty/luajit/bin/luarocks make \
    && make install \
    && cp bin/kong /usr/local/bin/kong \
    && chmod 755 /usr/local/bin/kong \
    && cd /tmp \
    && echo "==> IPv6 Capable luasocket..." \
    && curl -fSL https://github.com/diegonehab/luasocket/archive/master.tar.gz -o luasocket-master.tar.gz \
    && tar xzf luasocket-master.tar.gz \
    && cd /tmp/luasocket-master \
    && /usr/local/openresty/luajit/bin/luarocks make \
    && cd /tmp \
    && rm -rf \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        luarocks-${LUAROCKS_VERSION}.tar.gz luarocks-${LUAROCKS_VERSION} \
        kong-${KONG_VERSION}.tar.gz kong-${KONG_VERSION} \
        luasocket-master.tar.gz luasocket-master \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* \
    && mkdir -p /usr/local/kong/logs \
    && ln -sf /dev/stdout /usr/local/kong/logs/access.log \
    && ln -sf /dev/stderr /usr/local/kong/logs/error.log

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80 443 8444

STOPSIGNAL SIGTERM

CMD ["kong", "docker-start"]
