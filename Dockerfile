#syntax=docker/dockerfile:1.2
FROM debian:bookworm-slim as base

FROM base

COPY --chown=root:root --chmod=0755 ./protonwire /usr/bin/protonwire
COPY --chown=root:root --chmod=0755 ./entrypoint.sh /entrypoint.sh

RUN    DEBIAN_FRONTEND=noninteractive apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -qq --no-install-recommends --yes \
    && DEBIAN_FRONTEND=noninteractive apt-get install -qq --no-install-recommends --yes \
         bind9-host \
         ca-certificates \
         curl \
         htop \
         grep \
         gawk \
         htop \
         iproute2 \
         iputils-ping \
         jq \
         libcap2-bin \
         moreutils \
         natpmpc \
         netcat-openbsd \
         openresolv \
         procps \
         socat \
         util-linux \
         wireguard-tools \
    && apt-get auto-clean \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/protonwire /usr/bin/protonvpn

CMD [ "/entrypoint.sh" ]
