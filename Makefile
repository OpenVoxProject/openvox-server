include dev-resources/Makefile.i18n

.PHONY: version dist jar clean

WORKDIR := target
VERSION := $(shell awk --field-separator '"' '/def ps-version/ { print $$2 }' project.clj)
JAR := $(shell awk --field-separator '"' '/:uberjar-name/ { print $$2 }' project.clj)

version:
	@echo $(VERSION)

clean:
	rm -rf $(WORKDIR)

jar: $(WORKDIR)/$(JAR)

dist: $(WORKDIR)/puppetserver-$(VERSION).tar.gz

%.tar.gz: $(WORKDIR)/$(JAR) $(wildcard to-ship/*)
	mkdir -p $(WORKDIR)/$*
	cp -r $^ $(WORKDIR)/$*/
	tar cf $@ -C $(WORKDIR) $*

$(WORKDIR)/$(JAR):
	lein uberjar
