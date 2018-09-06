#!/bin/sh
set -e

export KONG_NGINX_DAEMON=off
export KONG_ANONYMOUS_REPORTS=false
export KONG_HTTP2=on 
export KONG_PROXY_LISTEN='[::]:80, [::]:443 http2 ssl' 
export KONG_ADMIN_LISTEN='[::]:444 ssl'

if [[ "$1" == "kong" ]]; then
  PREFIX=${KONG_PREFIX:=/usr/local/kong}
  mkdir -p $PREFIX

  if [[ "$2" == "docker-start" ]]; then
    kong prepare -p $PREFIX

    exec /usr/local/openresty/nginx/sbin/nginx \
      -p $PREFIX \
      -c nginx.conf
  fi
fi

exec "$@"
