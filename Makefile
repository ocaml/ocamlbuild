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

OCAMLC    = ocamlc
OCAMLOPT  = ocamlopt
OCAMLDEP  = ocamldep
OCAMLLEX  = ocamllex
CP        = cp
COMPFLAGS= -w L -w R -w Z -I src -I +unix -safe-string
LINKFLAGS= -I +unix -I src

LIBDIR=$(shell ocamlc -where)
BINDIR?=/usr/local/bin

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
  ocamlbuildlib.cmxa ocamlbuildlib.$(A) \
  src/ocamlbuild.cmx src/ocamlbuild.$(O) \
  ocamlbuild_pack.cmx \
  $(EXTRA_CMO:.cmo=.cmx) $(EXTRA_CMO:.cmo=.$(O))

INSTALL_LIBDIR=$(DESTDIR)$(LIBDIR)/ocamlbuild
INSTALL_BINDIR=$(DESTDIR)$(BINDIR)

all: ocamlbuild.byte ocamlbuildlib.cma
                 # ocamlbuildlight.byte ocamlbuildlightlib.cma
allopt: ocamlbuild.native ocamlbuildlib.cmxa

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

src/ocamlbuild_config.ml: Makefile.create_config VERSION
	make -f Makefile.create_config "LIBDIR=$(LIBDIR)" src/ocamlbuild_config.ml
clean::
	rm -f src/ocamlbuild_config.ml
beforedepend:: src/ocamlbuild_config.ml

# Installation

install:
	mkdir -p $(INSTALL_BINDIR)
	$(CP) ocamlbuild.byte $(INSTALL_BINDIR)/ocamlbuild$(EXE)
	$(CP) ocamlbuild.byte $(INSTALL_BINDIR)/ocamlbuild.byte$(EXE)
	mkdir -p $(INSTALL_LIBDIR)
	$(CP) $(INSTALL_LIB) $(INSTALL_LIBDIR)/

installopt:
	if test -f ocamlbuild.native; then $(MAKE) installopt_really; fi

findlib-install:
	ocamlfind install ocamlbuild META $(INSTALL_LIB)

installopt_really:
	$(CP) ocamlbuild.native $(INSTALL_BINDIR)/ocamlbuild$(EXE)
	$(CP) ocamlbuild.native $(INSTALL_BINDIR)/ocamlbuild.native$(EXE)
	mkdir -p $(INSTALL_LIBDIR)
	$(CP) $(INSTALL_LIB_OPT) $(INSTALL_LIBDIR)/

# The generic rules

.SUFFIXES: .ml .mli .cmo .cmi .cmx

.ml.cmo:
	$(OCAMLC) $(COMPFLAGS) -c $<

.mli.cmi:
	$(OCAMLC) $(COMPFLAGS) -c $<

.ml.cmx:
	$(OCAMLOPT) -for-pack Ocamlbuild_pack $(COMPFLAGS) -c $<

clean::
	rm -f src/*.cm? *.$(O) *.cm* *.$(A)
	rm -f *.byte *.native
	rm -f test/test2/vivi.ml

# The dependencies

depend: beforedepend
	$(OCAMLDEP) -I src src/*.mli src/*.ml > .depend

$(EXTRA_CMI): ocamlbuild_pack.cmi
$(EXTRA_CMO): ocamlbuild_pack.cmo ocamlbuild_pack.cmi
$(EXTRA_CMX): ocamlbuild_pack.cmx ocamlbuild_pack.cmi

include .depend

.PHONY: all allopt clean beforedepend
.PHONY: install installopt installopt_really depend

