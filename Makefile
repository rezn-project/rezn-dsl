APP_NAME=rezndsl
APP_NAME_CLI=rezndsl-cli
VERSION?=$(subst -,~, $(subst v,,$(RAW_VERSION)))
ARCH?=amd64
BUILD_DIR=_build/default
STAGING_DIR=dist/deb/$(APP_NAME)
DEB_NAME=$(APP_NAME)_$(VERSION)_$(ARCH).deb
CLI_BUILD_DIR=cli

.PHONY: all build stage deb clean

all: build stage deb

build:
	dune build

stage:
	rm -rf $(STAGING_DIR)
	mkdir -p $(STAGING_DIR)/opt/$(APP_NAME)/bin
	mkdir -p $(STAGING_DIR)/opt/$(APP_NAME_CLI)/bin
	mkdir -p $(STAGING_DIR)/etc/$(APP_NAME)
	mkdir -p $(STAGING_DIR)/lib/systemd/system
	mkdir -p $(STAGING_DIR)/etc/logrotate.d

	cp $(BUILD_DIR)/server/main.exe $(STAGING_DIR)/opt/$(APP_NAME)/bin/server
	cp $(BUILD_DIR)/reznc/main.exe $(STAGING_DIR)/opt/$(APP_NAME_CLI)/bin/reznc
	cp $(BUILD_DIR)/verify/main.exe $(STAGING_DIR)/opt/$(APP_NAME_CLI)/bin/rezn-verify
	cp packaging/$(APP_NAME).env.default $(STAGING_DIR)/etc/$(APP_NAME)/$(APP_NAME).env.default
	cp packaging/$(APP_NAME).service $(STAGING_DIR)/lib/systemd/system/$(APP_NAME).service
	cp packaging/$(APP_NAME).logrotate $(STAGING_DIR)/etc/logrotate.d/$(APP_NAME)

	cp packaging/postinst.sh postinst.sh
	cp packaging/postrm.sh postrm.sh

	chmod +x postinst.sh postrm.sh

	chmod +x $(STAGING_DIR)/opt/$(APP_NAME)/bin/server
	chmod +x $(STAGING_DIR)/opt/$(APP_NAME_CLI)/bin/reznc
	chmod +x $(STAGING_DIR)/opt/$(APP_NAME_CLI)/bin/rezn-verify

deb:
	fpm -s dir -t deb \
	  -n $(APP_NAME) \
	  -v $(VERSION) \
	  -a $(ARCH) \
	  --license "MIT" \
	  --description "Rezn DSL converts .rezn files into signed JSON IR" \
	  --after-install postinst.sh \
	  --after-remove postrm.sh \
	  $(STAGING_DIR)/opt/$(APP_NAME)/=/opt/$(APP_NAME)/ \
	  $(STAGING_DIR)/opt/$(APP_NAME_CLI)/=/opt/$(APP_NAME_CLI)/ \
	  $(STAGING_DIR)/etc/$(APP_NAME)/=/etc/$(APP_NAME)/ \
	  $(STAGING_DIR)/lib/systemd/system/$(APP_NAME).service=/lib/systemd/system/$(APP_NAME).service \
	  $(STAGING_DIR)/etc/logrotate.d/$(APP_NAME)=/etc/logrotate.d/$(APP_NAME)

	rm -f postinst.sh postrm.sh

clean:
	rm -rf dist
	rm -f *.deb
	rm -f postinst.sh postrm.sh