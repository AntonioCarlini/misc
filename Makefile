GIT_UNTRACKED_FILES = $(shell git ls-files --others)

ARCHIVE_EXCLUSION_FILES += .gitignore
ARCHIVE_EXCLUSION_FILES += .git
ARCHIVE_EXCLUSION_FILES += bin             # not strictly required

ARCHIVE_EXCLUSION_FILES += ${GIT_UNTRACKED_FILES}

ARCHIVE_EXCLUSION_LIST = $(addprefix --exclude=,${ARCHIVE_EXCLUSION_FILES})

all: bundle run 

bundle: bin/misc.bundle
.PHONY: bin/misc.bundle

run: bin/standard-install-bundle.run
.PHONY: bin/standard-install-bundle.run

saa: bin/standard-install-archive.run
.PHONY: bin/standard-install-archive.run

bin/misc.bundle:
	@mkdir -p bin
	git bundle create $@ master
	cp admin/standard-install.sh bin/standard-install.sh

bin/standard-install-bundle.run: bin/misc.bundle
	@mkdir -p bin/makeself
	cp bin/misc.bundle bin/makeself/.
	cp ./admin/standard-install.sh bin/makeself/.
	cp ./admin/standard-install-for-makeself.sh bin/makeself/.
	chmod a+x bin/makeself/standard-install-for-makeself.sh
	makeself --nox11 bin/makeself/ bin/standard-install-bundle.run "misc repo installer" ./standard-install-for-makeself.sh bundle

bin/standard-install-archive.run:
	makeself --nox11 --tar-extra "${ARCHIVE_EXCLUSION_LIST}" . bin/standard-install-archive.run "misc repo installer" ./admin/standard-install-for-makeself.sh archive
