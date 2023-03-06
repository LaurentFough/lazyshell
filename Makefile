NAME=lazyshell

INSTALL?=install -c
PREFIX?=/usr/local
SHARE_DIR?=$(DESTDIR)$(PREFIX)/share/$(NAME)
DOC_DIR?=$(DESTDIR)$(PREFIX)/share/doc/$(NAME)
ZSH?=zsh # zsh binary to run tests with


install:
	$(INSTALL) -d $(SHARE_DIR)
	cp .version zsh-syntax-highlighting.zsh $(SHARE_DIR)
	cp README.md $(DOC_DIR)
	sed -e '1s/ .*//' -e '/^\[build-status-[a-z]*\]: /d' < README.md > $(DOC_DIR)/README.md
	if [ x"true" = x"`git rev-parse --is-inside-work-tree 2>/dev/null`" ]; then \
		git rev-parse HEAD; \
	else \
		cat .revision-hash; \
	fi > $(SHARE_DIR)/.revision-hash

.PHONY: install
