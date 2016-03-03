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

OCAMLBUILD_LIBDIR:=$(LIBDIR)
OCAMLBUILD_BINDIR:=$(BINDIR)

# this configuration file is generated from configure.make
include Makefile.config

ifeq ($(OCAML_NATIVE_TOOLS), true)
OCAMLC    ?= ocamlc.opt
OCAMLOPT  ?= ocamlopt.opt
OCAMLDEP  ?= ocamldep.opt
OCAMLLEX  ?= ocamllex.opt
else
OCAMLC    ?= ocamlc
OCAMLOPT  ?= ocamlopt
OCAMLDEP  ?= ocamldep
OCAMLLEX  ?= ocamllex
endif

CP        ?= cp
COMPFLAGS ?= -w L -w R -w Z -I src -I +unix -safe-string
LINKFLAGS ?= -I +unix -I src

PACK_CMO= $(addprefix src/,\
  const.cmo \
  loc.cmo \
  discard_printf.cmo \
  signatures.cmi \
  my_std.cmo \
  my_unix.cmo \
  tags.cmo \
  display.cmo \
  log.cmo \
  shell.cmo \
  bool.cmo \
  glob_ast.cmo \
  glob_lexer.cmo \
  glob.cmo \
  lexers.cmo \
  param_tags.cmo \
  command.cmo \
  ocamlbuild_config.cmo \
  ocamlbuild_where.cmo \
  slurp.cmo \
  options.cmo \
  pathname.cmo \
  configuration.cmo \
  flags.cmo \
  hygiene.cmo \
  digest_cache.cmo \
  resource.cmo \
  rule.cmo \
  solver.cmo \
  report.cmo \
  tools.cmo \
  fda.cmo \
  findlib.cmo \
  ocaml_arch.cmo \
  ocaml_utils.cmo \
  ocaml_dependencies.cmo \
  ocaml_compiler.cmo \
  ocaml_tools.cmo \
  ocaml_specific.cmo \
  plugin.cmo \
  exit_codes.cmo \
  hooks.cmo \
  main.cmo \
  )

EXTRA_CMO=$(addprefix src/,\
  ocamlbuild_plugin.cmo \
  ocamlbuild_executor.cmo \
  ocamlbuild_unix_plugin.cmo \
  )

PACK_CMX=$(PACK_CMO:.cmo=.cmx)
EXTRA_CMX=$(EXTRA_CMO:.cmo=.cmx)
EXTRA_CMI=$(EXTRA_CMO:.cmo=.cmi)

INSTALL_LIB=\
  ocamlbuildlib.cma \
  src/ocamlbuild.cmo \
  ocamlbuild_pack.cmi \
  $(EXTRA_CMO:.cmo=.cmi)

INSTALL_LIB_OPT=\
  ocamlbuildlib.cmxa ocamlbuildlib$(EXT_LIB) \
  src/ocamlbuild.cmx src/ocamlbuild$(EXT_OBJ) \
  ocamlbuild_pack.cmx \
  $(EXTRA_CMO:.cmo=.cmx) $(EXTRA_CMO:.cmo=$(EXT_OBJ))

INSTALL_LIBDIR=$(DESTDIR)$(LIBDIR)
INSTALL_BINDIR=$(DESTDIR)$(BINDIR)

ifeq ($(OCAML_NATIVE), true)
all: byte native
else
all: byte
endif

byte: ocamlbuild.byte ocamlbuildlib.cma
                 # ocamlbuildlight.byte ocamlbuildlightlib.cma
native: ocamlbuild.native ocamlbuildlib.cmxa

allopt: byte alias # compatibility alias

# The executables

ocamlbuild.byte: ocamlbuild_pack.cmo $(EXTRA_CMO) src/ocamlbuild.cmo
	$(OCAMLC) $(LINKFLAGS) -o ocamlbuild.byte \
          unix.cma ocamlbuild_pack.cmo $(EXTRA_CMO) src/ocamlbuild.cmo

ocamlbuildlight.byte: ocamlbuild_pack.cmo ocamlbuildlight.cmo
	$(OCAMLC) $(LINKFLAGS) -o ocamlbuildlight.byte \
          ocamlbuild_pack.cmo ocamlbuildlight.cmo

ocamlbuild.native: ocamlbuild_pack.cmx $(EXTRA_CMX) src/ocamlbuild.cmx
	$(OCAMLOPT) $(LINKFLAGS) -o ocamlbuild.native \
          unix.cmxa ocamlbuild_pack.cmx $(EXTRA_CMX) src/ocamlbuild.cmx

# The libraries

ocamlbuildlib.cma: ocamlbuild_pack.cmo $(EXTRA_CMO)
	$(OCAMLC) -a -o ocamlbuildlib.cma \
          ocamlbuild_pack.cmo $(EXTRA_CMO)

ocamlbuildlightlib.cma: ocamlbuild_pack.cmo ocamlbuildlight.cmo
	$(OCAMLC) -a -o ocamlbuildlightlib.cma \
          ocamlbuild_pack.cmo ocamlbuildlight.cmo

ocamlbuildlib.cmxa: ocamlbuild_pack.cmx $(EXTRA_CMX)
	$(OCAMLOPT) -a -o ocamlbuildlib.cmxa \
          ocamlbuild_pack.cmx $(EXTRA_CMX)

# The packs

ocamlbuild_pack.cmo: $(PACK_CMO)
	$(OCAMLC) -pack $(PACK_CMO) -o ocamlbuild_pack.cmo

ocamlbuild_pack.cmi: ocamlbuild_pack.cmo

ocamlbuild_pack.cmx: $(PACK_CMX)
	$(OCAMLOPT) -pack $(PACK_CMX) -o ocamlbuild_pack.cmx

# The lexers

src/lexers.ml: src/lexers.mll
	$(OCAMLLEX) src/lexers.mll
clean::
	rm -f src/lexers.ml
beforedepend:: src/lexers.ml

src/glob_lexer.ml: src/glob_lexer.mll
	$(OCAMLLEX) src/glob_lexer.mll
clean::
	rm -f src/glob_lexer.ml
beforedepend:: src/glob_lexer.ml

# The config file

configure: Makefile.config src/ocamlbuild_config.ml

Makefile.config src/ocamlbuild_config.ml:
	$(MAKE) -f configure.make $@

clean::
	rm -f Makefile.config src/ocamlbuild_config.ml

beforedepend:: src/ocamlbuild_config.ml

# Installation

# The binaries go in BINDIR. We copy ocamlbuild.byte and
# ocamlbuild.native (if available), and also copy the best available
# binary as BINDIR/ocamlbuild.

# The library is put in LIBDIR/ocamlbuild. We copy
# - the META file (for ocamlfind)
# - src/signatures.mli (user documentation)
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

install-bin-opam:
	echo 'bin: [' >> ocamlbuild.install
	echo '  "ocamlbuild.byte" {"ocamlbuild.byte"}' >> ocamlbuild.install
ifeq ($(OCAML_NATIVE), true)
	echo '  "ocamlbuild.native" {"ocamlbuild.native"}' >> ocamlbuild.install
	echo '  "ocamlbuild.native" {"ocamlbuild"}' >> ocamlbuild.install
else
	echo '  "ocamlbuild.byte" {"ocamlbuild"}' >> ocamlbuild.install
endif
	echo ']' >> ocamlbuild.install
	echo >> ocamlbuild.install

install-lib-basics:
	mkdir -p $(INSTALL_LIBDIR)/ocamlbuild
	$(CP) META src/signatures.mli $(INSTALL_LIBDIR)/ocamlbuild

install-lib-basics-opam:
	echo '  "META"' >> ocamlbuild.install
	echo '  "src/signatures.mli" {"signatures.mli"}' >> ocamlbuild.install

install-lib-byte:
	mkdir -p $(INSTALL_LIBDIR)/ocamlbuild
	$(CP) $(INSTALL_LIB) $(INSTALL_LIBDIR)/ocamlbuild

install-lib-byte-opam:
	for lib in $(INSTALL_LIB); do \
	  echo "  \"$$lib\" {\"$$(basename $$lib)\"}" >> ocamlbuild.install; \
	done

install-lib-native:
	mkdir -p $(INSTALL_LIBDIR)/ocamlbuild
	$(CP) $(INSTALL_LIB_OPT) $(INSTALL_LIBDIR)/ocamlbuild

install-lib-native-opam:
	for lib in $(INSTALL_LIB_OPT); do \
	  echo "  \"$$lib\" {\"$$(basename $$lib)\"}" >> ocamlbuild.install; \
	done

ifeq ($(OCAML_NATIVE), true)
install-lib: install-lib-basics install-lib-byte install-lib-native
else
install-lib: install-lib-basics install-lib-byte
endif

install-lib-findlib:
ifeq ($(OCAML_NATIVE), true)
	ocamlfind install ocamlbuild \
	  META src/signatures.mli $(INSTALL_LIB) $(INSTALL_LIB_OPT)
else
	ocamlfind install ocamlbuild \
	  META src/signatures.mli $(INSTALL_LIB)
endif

install-lib-opam:
	echo 'lib: [' >> ocamlbuild.install
	$(MAKE) install-lib-basics-opam
	$(MAKE) install-lib-byte-opam
ifeq ($(OCAML_NATIVE), true)
	$(MAKE) install-lib-native-opam
endif
	echo ']' >> ocamlbuild.install
	echo >> ocamlbuild.install

uninstall-bin:
	rm $(BINDIR)/ocamlbuild
	rm $(BINDIR)/ocamlbuild.byte
ifeq ($(OCAML_NATIVE), true)
	rm $(BINDIR)/ocamlbuild.native
endif

uninstall-lib-basics:
	rm $(LIBDIR)/ocamlbuild/META $(LIBDIR)/ocamlbuild/signatures.mli

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

install: check-if-preinstalled
	$(MAKE) install-bin install-lib
uninstall: uninstall-bin uninstall-lib

findlib-install: check-if-preinstalled
	$(MAKE) install-bin install-lib-findlib
findlib-uninstall: uninstall-bin uninstall-lib-findlib

opam-install: check-if-preinstalled
	$(MAKE) ocamlbuild.install

ocamlbuild.install:
	rm -f ocamlbuild.install
	touch ocamlbuild.install
	$(MAKE) install-bin-opam
	$(MAKE) install-lib-opam

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

# The generic rules

.SUFFIXES: .ml .mli .cmo .cmi .cmx

.ml.cmo:
	$(OCAMLC) $(COMPFLAGS) -c $<

.mli.cmi:
	$(OCAMLC) $(COMPFLAGS) -c $<

.ml.cmx:
	$(OCAMLOPT) -for-pack Ocamlbuild_pack $(COMPFLAGS) -c $<

clean::
	rm -f src/*.cm? *.cm*
ifdef EXT_OBJ
	rm -f src/*$(EXT_OBJ) *$(EXT_OBJ)
endif
ifdef EXT_LIB
	rm -f src/*$(EXT_LIB) *$(EXT_LIB)
endif
	rm -f *.byte *.native
	rm -f test/test2/vivi.ml
	rm -f ocamlbuild.install

# The dependencies

depend: beforedepend
	$(OCAMLDEP) -I src src/*.mli src/*.ml > .depend

$(EXTRA_CMI): ocamlbuild_pack.cmi
$(EXTRA_CMO): ocamlbuild_pack.cmo ocamlbuild_pack.cmi
$(EXTRA_CMX): ocamlbuild_pack.cmx ocamlbuild_pack.cmi

include .depend

.PHONY: all allopt clean beforedepend
.PHONY: install installopt installopt_really depend

