MAIN_CFLAGS := -Os -Wall $(shell pkg-config fuse --cflags)
MAIN_CPPFLAGS := -Wall -Wno-unused-function -Wconversion -Wtype-limits -DUSE_AUTH -D_XOPEN_SOURCE=700 -D_ISOC99_SOURCE
THR_CPPFLAGS := -DUSE_THREAD
THR_LDFLAGS := -lpthread
MAIN_LDFLAGS := $(shell pkg-config fuse --libs | sed -e s/-lrt// -e s/-ldl// -e s/-pthread// -e "s/  / /g")

ifeq ($(shell pkg-config --atleast-version 2.10 gnutls ; echo $$?), 0)
    CERT_STORE := /etc/ssl/certs/ca-certificates.crt
    SSL_CPPFLAGS := -DUSE_SSL $(shell pkg-config gnutls --cflags) -DCERT_STORE=\"$(CERT_STORE)\"
    SSL_LDFLAGS := $(shell pkg-config gnutls --libs)
endif

OS := $(shell uname)
ifeq ($(OS),Darwin)
   MAIN_CFLAGS += -ObjC
   MAIN_LDFLAGS += -framework Foundation
endif

targets = httpfs2 httpfs2.1

all: $(targets)

httpfs2: httpfs2.c
	$(CC) $(MAIN_CPPFLAGS) $(CPPFLAGS) $(SSL_CPPFLAGS) $(THR_CPPFLAGS) $(MAIN_CFLAGS) $(CFLAGS) $< $(MAIN_LDFLAGS) $(LDFLAGS) $(THR_LDFLAGS) $(SSL_LDFLAGS) -o $@

clean:
	rm -f $(targets)

httpfs2.1: httpfs2.pod
	pod2man -c '' -r '' -d `date -r $< +"%x"` $< $@

# Rules to automatically make a Debian package
# Avoid setting these on MacOS as it has no parsechangelog or dpkg commands
ifneq ($(OS),Darwin)
	package = $(shell dpkg-parsechangelog | grep ^Source: | sed -e s,'^Source: ',,)
	version = $(shell dpkg-parsechangelog | grep ^Version: | sed -e s,'^Version: ',, -e 's,-.*,,')
	revision = $(shell dpkg-parsechangelog | grep ^Version: | sed -e s,'.*-',,)
	architecture = $(shell dpkg --print-architecture)
	tar_dir = $(package)-$(version)
	tar_gz   = $(tar_dir).tar.gz
	pkg_deb_dir = pkgdeb
	unpack_dir  = $(pkg_deb_dir)/$(tar_dir)
	orig_tar_gz = $(pkg_deb_dir)/$(package)_$(version).orig.tar.gz
	pkg_deb_src = $(pkg_deb_dir)/$(package)_$(version)-$(revision)_source.changes
	pkg_deb_bin = $(pkg_deb_dir)/$(package)_$(version)-$(revision)_$(architecture).changes
	deb_pkg_key = CB8C5858
endif

debclean:
	rm -rf $(pkg_deb_dir)

deb: debsrc debbin

debbin: $(unpack_dir)
	cd $(unpack_dir) && dpkg-buildpackage -b -k$(deb_pkg_key)

debsrc: $(unpack_dir)
	cd $(unpack_dir) && dpkg-buildpackage -S -k$(deb_pkg_key)

$(unpack_dir): $(orig_tar_gz)
	tar -zxf $(orig_tar_gz) -C $(pkg_deb_dir)

$(pkg_deb_dir):
	mkdir $(pkg_deb_dir)

$(pkg_deb_dir)/$(tar_gz): $(pkg_deb_dir)
	git archive --format=tgz -o $(pkg_deb_dir)/$(tar_gz) HEAD

$(orig_tar_gz): $(pkg_deb_dir)/$(tar_gz)
	ln -s $(tar_gz) $(orig_tar_gz)

