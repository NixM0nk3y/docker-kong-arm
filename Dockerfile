#
#
#

FROM arm32v6/alpine:3.11.6

LABEL maintainer="Nick Gregory <docker@openenterprise.co.uk>"

ARG KONG_VERSION="master"
ARG KONG_REPO="https://github.com/NixM0nk3y/kong.git"

ARG LUAROCKS_VERSION="3.3.1"
ARG LUAROCKS_SHA256="eb20cd9814df05535d9aae98da532217c590fc07d48d90ca237e2a7cdcf284fe"

ARG RESTY_VERSION="1.15.8.3"
ARG RESTY_SHA256="b68cf3aa7878db16771c96d9af9887ce11f3e96a1e5e68755637ecaff75134a8"

ARG KONG_TLS_VERSION="0.0.6"
ARG KONG_TLS_SHA256="70aa3011ae95ae343e61dbe5f3f04609e3e7785a3f48de81f64ca95b048ff66e"

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
        yaml-dev \
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
        yaml \
        zlib \
        ca-certificates \
        unzip \
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
    && curl -vfSL https://luarocks.github.io/luarocks/releases/luarocks-${LUAROCKS_VERSION}.tar.gz -o luarocks-${LUAROCKS_VERSION}.tar.gz \
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
    && echo "==> Checking Out Kong..." \
    && git clone ${KONG_REPO} \
    && cd kong \
    && git checkout ${KONG_VERSION} \
    && /usr/local/openresty/luajit/bin/luarocks make \
    && make install \
    && cp bin/kong /usr/local/bin/kong \
    && chmod 755 /usr/local/bin/kong \
    && cd /tmp \
    && echo "==> Kong TLS module..." \
    && curl -fSL https://github.com/Kong/lua-kong-nginx-module/archive/${KONG_TLS_VERSION}.tar.gz -o lua-kong-nginx-module-${KONG_TLS_VERSION}.tar.gz \
    && echo "${KONG_TLS_SHA256}  lua-kong-nginx-module-${KONG_TLS_VERSION}.tar.gz" | sha256sum -c - \
    && tar xzf lua-kong-nginx-module-${KONG_TLS_VERSION}.tar.gz \
    && cd /tmp/lua-kong-nginx-module-${KONG_TLS_VERSION} \
    && LUA_LIB_DIR=/usr/local/openresty/lualib make install \
    && cd /tmp \
    && echo "==> IPv6 Capable luasocket..." \
    && curl -fSL https://github.com/diegonehab/luasocket/archive/master.tar.gz -o luasocket-master.tar.gz \
    && tar xzf luasocket-master.tar.gz \
    && cd /tmp/luasocket-master \
    && /usr/local/openresty/luajit/bin/luarocks make \
    && echo "==> Securing PGmoon..." \
    && sed -i.old -e 's/tlsv1/tlsv1_2/' /usr/local/openresty/luajit/share/lua/5.1/pgmoon/socket.lua \
    && cd /tmp \
    && rm -rf \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        luarocks-${LUAROCKS_VERSION}.tar.gz luarocks-${LUAROCKS_VERSION} \
        kong \
        lua-kong-nginx-module-${KONG_TLS_VERSION}.tar.gz lua-kong-nginx-module-${KONG_TLS_VERSION} \
        luasocket-master.tar.gz luasocket-master \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/* \
    && /usr/sbin/update-ca-certificates \
    && mkdir -p /usr/local/kong/logs \
    && ln -sf /dev/stdout /usr/local/kong/logs/access.log \
    && ln -sf /dev/stderr /usr/local/kong/logs/error.log

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80 443 8080 8443

STOPSIGNAL SIGTERM

CMD ["kong", "docker-start"]
