## Makefile to simplify Octave Forge package maintenance tasks
##
## Copyright 2015-2016 Carnë Draug
## Copyright 2015-2016 Oliver Heimlich
## Copyright 2015-2018 Mike Miller
##
## Copying and distribution of this file, with or without modification,
## are permitted in any medium without royalty provided the copyright
## notice and this notice are preserved.  This file is offered as-is,
## without any warranty.

MKOCTFILE := mkoctfile
OCTAVE    := octave
SED       := sed
SHA256SUM := sha256sum
TAR       := tar

PACKAGE := $(shell $(SED) -n -e 's/^Name: *\(\w\+\)/\1/p' DESCRIPTION)
VERSION := $(shell $(SED) -n -e 's/^Version: *\(\w\+\)/\1/p' DESCRIPTION)
DEPENDS := $(shell $(SED) -n -e 's/^Depends[^,]*, *\(.*\)/\1/p' DESCRIPTION | $(SED) 's/ *([^()]*)//g; s/ *, */ /g')

# TODO find GIT equivalents
#HG           := hg
#HG_CMD        = $(HG) --config alias.$(1)=$(1) --config defaults.$(1)= $(1)
#HG_ID        := $(shell $(call HG_CMD,identify) --id | sed -e 's/+//' )
#HG_TIMESTAMP := $(firstword $(shell $(call HG_CMD,log) --rev $(HG_ID) --template '{date|hgdate}'))

#TAR_REPRODUCIBLE_OPTIONS := --sort=name --mtime="@$(HG_TIMESTAMP)" --owner=0 --group=0 --numeric-owner
TAR_REPRODUCIBLE_OPTIONS := --sort=name --owner=0 --group=0 --numeric-owner
TAR_OPTIONS  := --format=ustar $(TAR_REPRODUCIBLE_OPTIONS)

RELEASE_DIR     := $(PACKAGE)-$(VERSION)
RELEASE_TARBALL := $(PACKAGE)-$(VERSION).tar.gz
HTML_DIR        := $(PACKAGE)-html
HTML_TARBALL    := $(PACKAGE)-html.tar.gz

.PHONY: help dist html release install all check doctest run doc clean maintainer-clean

help:
	@echo "Targets:"
	@echo "   dist             - Create $(RELEASE_TARBALL) for release"
	@echo "   html             - Create $(HTML_TARBALL) for release"
	@echo "   release          - Create both of the above and show md5sums"
	@echo
	@echo "   install          - Install the package in GNU Octave"
	@echo "   all              - Build all oct files"
	@echo "   check            - Execute package tests (w/o install)"
	@echo "   doctest          - Execute package doc tests (w/o install)"
	@echo "   run              - Run Octave with development in PATH (no install)"
	@echo "   doc              - Build Texinfo package manual"
	@echo
	@echo "   clean            - Remove releases, html documentation, and oct files"
	@echo "   maintainer-clean - Additionally remove all generated files"

# Create the unpacked package.
#
# Notes:
#    * having ".git/index" as a prerequesite means it is only rebuilt
#      if we are at a different commit.
#    * the variable RM usually defaults to "rm -f"
#    * having this recipe separate from the one that makes the tarball
#      makes it easy to have packages in alternative formats (such as zip)
#    * note that if a commands needs to be ran in a specific directory,
#      the command to "cd" needs to be on the same line.  Each line restores
#      the original working directory.
$(RELEASE_DIR): .git/index
	@echo "Creating package version $(VERSION) release ..."
	-rm -rf $@
	mkdir -p $@
	rsync -a -q --exclude='Makefile' * $@
	chmod -R a+rX,u+w,go-w $@

$(RELEASE_TARBALL): $(RELEASE_DIR)
	$(TAR) -cf - $(TAR_OPTIONS) $< | gzip -9n > $@
	-rm -rf $<

$(HTML_DIR): install
	@echo "Generating HTML documentation. This may take a while ..."
	-rm -rf $@
	$(OCTAVE) --silent \
	  --eval 'page_screen_output (false);' \
	  --eval 'set (0, "defaultfigurevisible", "off");' \
	  --eval 'pkg load generate_html $(PACKAGE);' \
	  --eval 'generate_package_html ("$(PACKAGE)", "$@", "octave-forge");'
	chmod -R a+rX,u+w,go-w $@

$(HTML_TARBALL): $(HTML_DIR)
	$(TAR) -cf - $(TAR_OPTIONS) $< | gzip -9n > $@
	-rm -rf $<

dist: $(RELEASE_TARBALL)

html: $(HTML_TARBALL)

release: dist html
	@$(SHA256SUM) $(RELEASE_TARBALL) $(HTML_TARBALL)
	@echo "Upload @ https://sourceforge.net/p/octave/package-releases/new/"
	@echo "Execute: git tag \"$(VERSION)\""

install: $(RELEASE_TARBALL)
	@echo "Installing package locally ..."
	$(OCTAVE) --silent --eval 'pkg install $(RELEASE_TARBALL);'

all:
	#cd src && $(MAKE) $@
	#cd src && $(MAKE) PKG_ADD PKG_DEL

check: all
	$(OCTAVE) --silent \
	  --eval 'if (! isempty ("$(DEPENDS)")); pkg load $(DEPENDS); endif;' \
	  --eval 'addpath (fullfile (pwd, "inst"));' \
	  #--eval 'addpath (fullfile (pwd, "src"));' \
	  --eval 'runtests ("inst"); #runtests ("src");'

doctest: all
	$(OCTAVE) --silent \
	  --eval 'if (! isempty ("$(DEPENDS)")); pkg load $(DEPENDS); endif;' \
	  --eval 'pkg load doctest;' \
	  --eval 'addpath (fullfile (pwd, "inst"));' \
	  --eval 'doctest ({"inst"});'
	  #--eval 'addpath (fullfile (pwd, "src"));' \
	  #--eval 'doctest ({"src", "inst"});'

run: all
	$(OCTAVE) --silent --persist \
	  --eval 'if (! isempty ("$(DEPENDS)")); pkg load $(DEPENDS); endif;' \
	  --eval 'addpath (fullfile (pwd, "inst"));' \
	  #--eval 'addpath (fullfile (pwd, "src"));'

doc:

clean:
	-rm -rf $(RELEASE_DIR) $(RELEASE_TARBALL) $(HTML_TARBALL) $(HTML_DIR)
	#cd src && $(MAKE) $@

maintainer-clean: clean
