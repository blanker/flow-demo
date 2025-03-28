FROM rust:1-bullseye AS builder

RUN apt-get update && apt-get install -y lua5.4 lua5.4-dev

RUN apt-get install -y libpq-dev

COPY luarocks-3.11.1.tar.gz .

RUN tar zxpf luarocks-3.11.1.tar.gz
RUN cd luarocks-3.11.1 && ./configure && make && make install
RUN luarocks install luasql-postgres PGSQL_INCDIR=/usr/include/postgresql LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4
RUN luarocks install lua-cjson LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4
RUN luarocks install luaossl LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4
RUN luarocks install jsonschema LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4

RUN luarocks install luasocket LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4
RUN luarocks install luasystem LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4
RUN luarocks install lua-mongo LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4

RUN lua -v
RUN luarocks --version
RUN luarocks list
