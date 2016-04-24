bundle: bin/misc.bundle

.PHONY: bin/misc.bundle

bin/misc.bundle:
	@mkdir -p bin
	git bundle create $@ master
	cp admin/standard-install.sh bin/standard-install.sh