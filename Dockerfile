FROM rust:1-bullseye AS builder

RUN apt-get update \
    && apt-get install -y lua5.4 lua5.4-dev \
    && apt-get install -y libpq-dev cmake clang libavcodec-dev libavformat-dev libavutil-dev libavdevice-dev pkg-config

COPY luarocks-3.11.1.tar.gz .
RUN tar zxpf luarocks-3.11.1.tar.gz \
    && cd luarocks-3.11.1 && ./configure && make && make install \
    && luarocks install luasql-postgres PGSQL_INCDIR=/usr/include/postgresql LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4 \
    && luarocks install lua-cjson LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4 \
    && luarocks install luaossl LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4 \
    && luarocks install jsonschema LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4 \
    && luarocks install luasocket LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4 \
    && luarocks install luasystem LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4 \
    && luarocks install uuid LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4

# 安装mongo-c-driver-1.27.6.tar.gz
COPY mongo-c-driver-1.27.6.tar.gz .
RUN tar zxf mongo-c-driver-1.27.6.tar.gz \
   && cd mongo-c-driver-1.27.6 \
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
   && luarocks install lua-mongo LIBBSON_DIR="$PREFIX" LIBMONGOC_DIR="$PREFIX" LUA_INCDIR=/usr/include/lua5.4 --force --lua-version=5.4

# 启用 contrib 和 non-free 仓库
# 设置自动接受微软字体 EULA
RUN sed -i 's/main/main contrib non-free/' /etc/apt/sources.list \
   && echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections \
   && apt-get update \
   && apt-get install -y libpq5 ca-certificates libavcodec-dev libavformat-dev libavutil-dev libavdevice-dev \
   && apt-get install -y strace fonts-noto libgl1-mesa-glx strace ttf-mscorefonts-installer \
   && apt-get install -y libxinerama1 libdbus-glib-1-2 libcups2 libcairo2 libsm6 libfontconfig1 libxrender1 libxext6 libfreetype6 \
   && apt-get install -y --no-install-recommends  wget gpg \
   && wget http://download.documentfoundation.org/libreoffice/stable/25.2.2/deb/x86_64/LibreOffice_25.2.2_Linux_x86-64_deb.tar.gz \
   && tar -xzf LibreOffice_*.tar.gz \
   && dpkg -i LibreOffice_*/DEBS/*.deb \
   && rm -rf LibreOffice_* \
   && apt-get purge -y wget \
   && apt-get autoremove -y \
   && apt-get clean \
   && rm -rf /var/lib/apt/lists/*   

# 安装lua 5.4.7
COPY lua-5.4.7.tar.gz .
RUN tar zxf lua-5.4.7.tar.gz \
    && cd lua-5.4.7 && make all test && make all install \
    && which lua

# 安装luarocks
COPY luarocks-3.11.1.tar.gz .
RUN tar zxpf luarocks-3.11.1.tar.gz \
    && cd luarocks-3.11.1 && ./configure && make && make install \
    && luarocks install luasql-postgres PGSQL_INCDIR=/usr/include/postgresql LUA_INCDIR=/usr/local/include --force --lua-version=5.4 \
    && luarocks install lua-cjson LUA_INCDIR=/usr/local/include --force --lua-version=5.4 \
    && luarocks install luaossl LUA_INCDIR=/usr/local/include --force --lua-version=5.4 \
    && luarocks install jsonschema LUA_INCDIR=/usr/local/include --force --lua-version=5.4 \
    && luarocks install luasocket LUA_INCDIR=/usr/local/include --force --lua-version=5.4 \
    && luarocks install luasystem LUA_INCDIR=/usr/local/include --force --lua-version=5.4

# 安装mongo-c-driver-1.27.6.tar.gz
COPY mongo-c-driver-1.27.6.tar.gz .
RUN tar zxf mongo-c-driver-1.27.6.tar.gz \
    && cd mongo-c-driver-1.27.6 \
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

RUN lua -v &&  luarocks --version && luarocks list

# 设置工作目录
WORKDIR /app
# 复制源代码
COPY . /app
# 编译项目
RUN cargo build
RUN cargo run --example test_imagesize
RUN cargo run --example test_ffmpeg

