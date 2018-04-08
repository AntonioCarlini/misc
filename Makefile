GIT_UNTRACKED_FILES = $(shell git ls-files --others)

ARCHIVE_EXCLUSION_FILES += .gitignore
ARCHIVE_EXCLUSION_FILES += .git
ARCHIVE_EXCLUSION_FILES += bin             # not strictly required

ARCHIVE_EXCLUSION_FILES += ${GIT_UNTRACKED_FILES}

ARCHIVE_EXCLUSION_LIST = $(addprefix --exclude=,${ARCHIVE_EXCLUSION_FILES})

bundle: bin/misc.bundle
.PHONY: bin/misc.bundle

sab: bin/standard-install-bundle.run
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
	rm $@
	makeself --nox11 --needroot bin/makeself/ bin/standard-install-bundle.run "misc repo installer" ./admin/standard-install-for-makeself.sh

bin/standard-install-archive.run:
	rm $@
	makeself --nox11 --needroot --tar-extra "${ARCHIVE_EXCLUSION_LIST}" . bin/standard-install-archive.run "misc repo installer" ./admin/standard-install-for-makeself.sh
