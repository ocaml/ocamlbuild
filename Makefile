#########################################################################
#                                                                       #
#                                 OCaml                                 #
#                                                                       #
#   Nicolas Pouillard, Berke Durak, projet Gallium, INRIA Rocquencourt  #
#                                                                       #
#   Copyright 2007 Institut National de Recherche en Informatique et    #
#   en Automatique.  All rights reserved.  This file is distributed     #
#  under the terms of the GNU Library General Public License, with      #
#  the special exception on linking described in file ../LICENSE.       #
#                                                                       #
#########################################################################

# see 'check-if-preinstalled' target
CHECK_IF_PREINSTALLED ?= true

JBUILDER ?= jbuilder

all:
	$(JBUILDER) build @install

byte: all # compatibility alias

native: all # compatibility alias

allopt: all # compatibility alias

distclean:: clean

clean::
	$(JBUILDER) clean

# man page

man: _build/install/default/man/man1/ocamlbuild.1

_build/install/default/man/man1/ocamlbuild.1:
	$(JBUILDER) build man/ocamlbuild.1

man/ocamlbuild.options.1: man/options_man.byte
	./man/options_man.byte > man/ocamlbuild.options.1

# Testing

test-%: testsuite/%.ml all
	$(JBUILDER) build testsuite/runtest-$*

test: all
	$(JBUILDER) runtest --no-buffer --display=short

# Installation

# The binaries go in BINDIR. We copy ocamlbuild.byte and
# ocamlbuild.native (if available), and also copy the best available
# binary as BINDIR/ocamlbuild.

# The library is put in LIBDIR/ocamlbuild. We copy
# - the META file (for ocamlfind)
# - src/signatures.{mli,cmi,cmti} (user documentation)
# - the files in INSTALL_LIB and INSTALL_LIB_OPT (if available)

# We support three installation methods:
# - standard {install,uninstall} targets
# - findlib-{install,uninstall} that uses findlib for the library install
# - producing an OPAM .install file and not actually installing anything

install-bin-byte:
	mkdir -p $(INSTALL_BINDIR)
	$(CP) ocamlbuild.byte $(INSTALL_BINDIR)/ocamlbuild.byte$(EXE)
ifneq ($(OCAML_NATIVE), true)
	$(CP) ocamlbuild.byte $(INSTALL_BINDIR)/ocamlbuild$(EXE)
endif

install-bin-native:
	mkdir -p $(INSTALL_BINDIR)
	$(CP) ocamlbuild.native $(INSTALL_BINDIR)/ocamlbuild$(EXE)
	$(CP) ocamlbuild.native $(INSTALL_BINDIR)/ocamlbuild.native$(EXE)

ifeq ($(OCAML_NATIVE), true)
install-bin: install-bin-byte install-bin-native
else
install-bin: install-bin-byte
endif

install-lib-basics:
	mkdir -p $(INSTALL_LIBDIR)/ocamlbuild
	$(CP) META $(INSTALL_SIGNATURES) $(INSTALL_LIBDIR)/ocamlbuild

install-lib-byte:
	mkdir -p $(INSTALL_LIBDIR)/ocamlbuild
	$(CP) $(INSTALL_LIB) $(INSTALL_LIBDIR)/ocamlbuild

install-lib-native:
	mkdir -p $(INSTALL_LIBDIR)/ocamlbuild
	$(CP) $(INSTALL_LIB_OPT) $(INSTALL_LIBDIR)/ocamlbuild

ifeq ($(OCAML_NATIVE), true)
install-lib: install-lib-basics install-lib-byte install-lib-native
else
install-lib: install-lib-basics install-lib-byte
endif

install-lib-findlib:
ifeq ($(OCAML_NATIVE), true)
	ocamlfind install ocamlbuild \
	  META $(INSTALL_SIGNATURES) $(INSTALL_LIB) $(INSTALL_LIB_OPT)
else
	ocamlfind install ocamlbuild \
	  META $(INSTALL_SIGNATURES) $(INSTALL_LIB)
endif

install-man:
	mkdir -p $(INSTALL_MANDIR)/man1
	cp man/ocamlbuild.1 $(INSTALL_MANDIR)/man1/ocamlbuild.1

uninstall-bin:
	rm $(BINDIR)/ocamlbuild
	rm $(BINDIR)/ocamlbuild.byte
ifeq ($(OCAML_NATIVE), true)
	rm $(BINDIR)/ocamlbuild.native
endif

uninstall-lib-basics:
	rm $(LIBDIR)/ocamlbuild/META
	for lib in $(INSTALL_SIGNATURES); do \
	  rm $(LIBDIR)/ocamlbuild/`basename $$lib`;\
	done

uninstall-lib-byte:
	for lib in $(INSTALL_LIB); do\
	  rm $(LIBDIR)/ocamlbuild/`basename $$lib`;\
	done

uninstall-lib-native:
	for lib in $(INSTALL_LIB_OPT); do\
	  rm $(LIBDIR)/ocamlbuild/`basename $$lib`;\
	done

uninstall-lib:
	$(MAKE) uninstall-lib-basics uninstall-lib-byte
ifeq ($(OCAML_NATIVE), true)
	$(MAKE) uninstall-lib-native
endif
	ls $(LIBDIR)/ocamlbuild # for easier debugging if rmdir fails
	rmdir $(LIBDIR)/ocamlbuild

uninstall-lib-findlib:
	ocamlfind remove ocamlbuild

uninstall-man:
	rm $(INSTALL_MANDIR)/man1/ocamlbuild.1

install: check-if-preinstalled
	$(MAKE) install-bin install-lib install-man
uninstall: uninstall-bin uninstall-lib uninstall-man

findlib-install: check-if-preinstalled
	$(MAKE) install-bin install-lib-findlib
findlib-uninstall: uninstall-bin uninstall-lib-findlib

opam-install: check-if-preinstalled
	$(JBUILDER) build ocamlbuild.install

check-if-preinstalled:
ifeq ($(CHECK_IF_PREINSTALLED), true)
	if test -d $(shell ocamlc -where)/ocamlbuild; then\
	  >&2 echo "ERROR: Preinstalled ocamlbuild detected at"\
	       "$(shell ocamlc -where)/ocamlbuild";\
	  >&2 echo "Installation aborted; if you want to bypass this"\
	        "safety check, pass CHECK_IF_PREINSTALLED=false to make";\
	  exit 2;\
	fi
endif

.PHONY: all allopt beforedepend clean configure test
.PHONY: install installopt installopt_really depend

