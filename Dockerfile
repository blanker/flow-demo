FROM rust:1-bullseye AS builder

# RUN apt-get update && apt-get install -y lua5.4 lua5.4-dev
RUN apt-get update
RUN apt-get install -y libpq-dev cmake

# 安装lua 5.4.7
COPY lua-5.4.7.tar.gz .
RUN tar zxf lua-5.4.7.tar.gz
RUN cd lua-5.4.7 && make all test && make all install
RUN which lua

# 安装luarocks
COPY luarocks-3.11.1.tar.gz .
RUN tar zxpf luarocks-3.11.1.tar.gz
RUN cd luarocks-3.11.1 && ./configure && make && make install
RUN luarocks install luasql-postgres PGSQL_INCDIR=/usr/include/postgresql LUA_INCDIR=/usr/local/include --force --lua-version=5.4
RUN luarocks install lua-cjson LUA_INCDIR=/usr/local/include --force --lua-version=5.4
RUN luarocks install luaossl LUA_INCDIR=/usr/local/include --force --lua-version=5.4
RUN luarocks install jsonschema LUA_INCDIR=/usr/local/include --force --lua-version=5.4

RUN luarocks install luasocket LUA_INCDIR=/usr/local/include --force --lua-version=5.4
RUN luarocks install luasystem LUA_INCDIR=/usr/local/include --force --lua-version=5.4

# 安装mongo-c-driver-1.27.6.tar.gz
COPY mongo-c-driver-1.27.6.tar.gz .
RUN tar zxf mongo-c-driver-1.27.6.tar.gz
RUN cd mongo-c-driver-1.27.6 \
    && export SOURCE=$(pwd) && echo $SOURCE \
    && export BUILD=$SOURCE/_build \
    && export VERSION="1.27.6" \
    && export PREFIX=$SOURCE/_install \
    && cmake -S $SOURCE -B $BUILD \
      -D ENABLE_EXTRA_ALIGNMENT=OFF \
      -D ENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF \
      -D CMAKE_BUILD_TYPE=RelWithDebInfo \
      -D BUILD_VERSION="$VERSION" \
      -D ENABLE_MONGOC=ON \
   && cmake --build $BUILD --config RelWithDebInfo --parallel \
   && cmake --install "$BUILD" --prefix "$PREFIX" --config RelWithDebInfo \
   && luarocks install lua-mongo LIBBSON_DIR="$PREFIX" LIBMONGOC_DIR="$PREFIX" LUA_INCDIR=/usr/local/include --force --lua-version=5.4
# RUN luarocks install lua-mongo LUA_INCDIR=/usr/local/include --force --lua-version=5.4

RUN lua -v
RUN luarocks --version
RUN luarocks list

# 设置工作目录
WORKDIR /app
# 复制源代码
COPY . /app
# 编译项目
RUN cargo build
RUN cargo run --example test_imagesize
RUN cargo run --example test_ffmpeg

