# Reference:
#  - multiarch https://actuated.dev/blog/multi-arch-docker-github-actions
FROM --platform=${BUILDPLATFORM:-linux/amd64} golang:1.21.1-alpine as builder

ARG BUILDPLATFORM \
    TARGETOS=linux \
    TARGETARCH=amd64 \
    FRP_VER=0.51.3 \
    GOTEMP_VER=3.11.3 \
    FRP_MULTIUSER_VER=0.0.2 \
    FRP_ALLOWED_PORTS_VER=1.0.2
    # GO_ACME_LEGO_VER=4.9.0

COPY plugins /src
RUN apk update && apk upgrade --no-cache && \
    apk --no-cache add build-base git gcc && \
    echo "build linknotifier" && cd /src/linknotifier && go mod tidy && go install && \
    env CGO_ENABLED=1 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -buildvcs -ldflags="-s -w" -o linknotifier && \
    echo "download frps" && mkdir /frp && cd /frp && \
    wget https://github.com/fatedier/frp/releases/download/v${FRP_VER}/frp_${FRP_VER}_${TARGETOS}_${TARGETARCH}.tar.gz -O /frp/frp.tar.gz && \
    tar -xvf frp.tar.gz && mv frp_${FRP_VER}_${TARGETOS}_${TARGETARCH}/* ./ && rm /frp/frp.tar.gz && \
    echo "download FRP_ALLOWED_PORTS" && \
    wget https://github.com/gainskills/frp_plugin_allowed_ports/releases/download/v${FRP_ALLOWED_PORTS_VER}/frps_allowed_ports_${TARGETOS}_${TARGETARCH}.tar.gz && \
    tar -xvf frps_allowed_ports_${TARGETOS}_${TARGETARCH}.tar.gz && \
    mv ./frps_allowed_ports_${TARGETOS}_${TARGETARCH}/frps_allowed_ports /usr/local/bin/frp_allowed_ports && \
    chmod +x /usr/local/bin/frp_allowed_ports && \
    rm -rf ./frps_allowed_ports_${TARGETOS}_${TARGETARCH} && rm frps_allowed_ports_${TARGETOS}_${TARGETARCH}.tar.gz && \
    echo "download gomplate" && \
    wget https://github.com/hairyhenderson/gomplate/releases/download/v${GOTEMP_VER}/gomplate_${TARGETOS}-${TARGETARCH}-slim -O /usr/local/bin/gotemp && \
    chmod +x /usr/local/bin/gotemp && \
    echo "download fp-multiuser" && \
    wget https://github.com/gofrp/fp-multiuser/releases/download/v${FRP_MULTIUSER_VER}/fp-multiuser-${TARGETOS}-${TARGETARCH} -O /usr/local/bin/fp-multiuser && \
    chmod +x /usr/local/bin/fp-multiuser
    # Using self build bin file due to unable to run git one
    # echo "download frp_plugin_allowed_ports" && \
    # wget https://github.com/Parmicciano/frp_plugin_allowed_ports/releases/download/Release/frp_plugin_allowed_ports -O /usr/local/bin/frp_allowed_ports && \
    # chmod +x /usr/local/bin/frp_allowed_ports
    # TO DO
    # echo "download go-acme lego" && mkdir /lego && cd /lego && \
    # wget https://github.com/go-acme/lego/releases/download/v${GO_ACME_LEGO_VER}/lego_v${GO_ACME_LEGO_VER}_${TARGETOS}_${TARGETARCH}.tar.gz -O /lego/lego.tar.gz && \
    # tar -xvf lego.tar.gz && chmod +x lego && rm /lego/lego.tar.gz

FROM --platform=${BUILDPLATFORM:-linux/amd64} alpine:latest
LABEL MAINTAINER="luka.cehovin@gmail.com kex_zh@outlook.com"
COPY --from=builder /frp/frps \
                #   /lego/lego \
                #   /src/portmanager/portmanager \
                  /usr/local/bin/frp_allowed_ports \
                  /src/linknotifier/linknotifier \
                  /usr/local/bin/fp-multiuser \
                  /usr/local/bin/gotemp \
                  /usr/local/bin/
COPY templates /data
COPY etc /etc
COPY start_runit /sbin/
RUN apk update && apk upgrade --no-cache && apk add --no-cache runit
CMD ["/sbin/start_runit"]

# docker build --force-rm -t frps:latest .