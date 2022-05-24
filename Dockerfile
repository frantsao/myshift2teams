FROM opensuse/leap:15.3 AS build
RUN \
  zypper in -y clang ldc dub zlib-devel libopenssl-devel ldc-phobos-devel
COPY . /usr/src
WORKDIR /usr/src
RUN DUB=/usr/bin/dub dub -v build

FROM opensuse/leap:15.3
RUN \
  groupadd -r nobody && \
  useradd -r -s /bin/false -g nobody nobody && \
  zypper in -y libz1 libopenssl1_1 libphobos2-ldc94
COPY --from=build /usr/src/myshift2teams /bin

USER nobody
ENTRYPOINT ["/bin/myshift2teams"]
