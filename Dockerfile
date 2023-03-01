FROM racket/racket:8.8 AS build

RUN raco pkg install --auto compiler-lib functional threading

RUN mkdir -p /app
WORKDIR /app
COPY fire-at-home-server.rkt /app
COPY fire-at-home/ /app/fire-at-home

RUN raco exe -o server fire-at-home-server.rkt
RUN raco dist dist-server server

FROM ubuntu:18.04

RUN apt update && \
    apt install -y libtinfo5 libfontconfig \
        libcairo2 libjpeg62 libglib2.0-0 libpango-1.0-0 \
        libpangocairo-1.0.0 libssl-dev

RUN mkdir -p /usr/src/app

COPY --from=build /app/dist-server/ /usr/src/app/

WORKDIR /usr/src/app

RUN mkdir -p /usr/src/app/static/img
RUN chmod +x /usr/src/app/bin/server
RUN ./bin/server