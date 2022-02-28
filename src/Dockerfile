FROM ubuntu:focal AS build
WORKDIR /root
RUN apt-get update && apt-get install -y \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

COPY Makefile /root/
COPY common.hpp /root/
COPY http-client.cpp /root/
COPY http-server.cpp /root/

RUN make

FROM ubuntu:focal

COPY --from=build /root/http-client /usr/local/bin/
COPY --from=build /root/http-server /usr/local/bin/

VOLUME ["/srv"]
WORKDIR "/srv"

CMD ["http-server"] 