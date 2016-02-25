# This file serve as a ./configure file, written as a GNU Makefile.
# It generates a local Makefile.config file that will be included by
# the main Makefile.

# Note: we initially included `ocamlc -where`/Makefile.config directly
# from the main Makefile, but this made it not robust to addition of
# new variables to this ocaml/Makefile.config that we do not control.

include $(shell ocamlc -where)/Makefile.config

OCAML_PREFIX = $(PREFIX)
OCAML_BINDIR = $(BINDIR)
OCAML_LIBDIR = $(LIBDIR)

# If you want to affect ocamlbuild's configuration by passing variable
# assignments to this Makefile, you probably want to define those
# OCAMLBUILD_* variables.

OCAMLBUILD_PREFIX ?= $(PREFIX)
OCAMLBUILD_BINDIR ?= \
  $(or $(shell opam config var bin 2>/dev/null),\
       $(PREFIX)/bin)
OCAMLBUILD_LIBDIR ?= \
  $(or $(shell opam config var lib 2>/dev/null),\
       $(shell ocamlfind printconf destdir 2>/dev/null),\
       $(LIBDIR))

# It is important to distinguish OCAML_LIBDIR, which points to the
# directory of the ocaml compiler distribution, and OCAMLBUILD_LIBDIR,
# which should be the general library directory of OCaml projects on
# the user machine.
#
# When ocamlbuild was distributed as part of the OCaml compiler
# distribution, there was only one LIBDIR variable, which now
# corresponds to OCAML_LIBDIR.
#
# In particular, plugin compilation would link
# LIBDIR/ocamlbuild/ocamlbuild.cma. For an ocamlbuild distributed as
# part of the compiler distribution, this LIBDIR occurence must be
# interpreted as OCAML_LIBDIR; but with a separate ocamlbuild, it must
# be interpreted as OCAMLBUILD_LIBDIR, as this is where ocamlbuild
# libraries will be installed.
#
# In the generated configuration files, we export
# OCAMLBUILD_{PREFIX,BINDIR,LIBDIR}, which are the ones that should
# generally be used, as the shorted names {PREFIX,BINDIR,LIBDIR}.

# if run from a git development repository,
# prefer $(git describe --always --dirty)
# to the VERSION file. This trick comes from Daniel Bünzli.
VERSION ?= \
  $(or $(shell git describe --tags --always --dirty 2>/dev/null),\
       $(shell ocaml scripts/cat.ml VERSION))

ifeq ($(ARCH), none)
OCAML_NATIVE ?= false
else
OCAML_NATIVE ?= true
endif

OCAML_NATIVE_TOOLS ?= $(OCAML_NATIVE)

Makefile.config:
	(echo "# This file was generated from configure.make"; \
	echo ;\
	echo "OCAML_PREFIX=$(OCAML_PREFIX)"; \
	echo "OCAML_BINDIR=$(OCAML_BINDIR)"; \
	echo "OCAML_LIBDIR=$(OCAML_LIBDIR)"; \
	echo ;\
	echo "EXT_OBJ=$(EXT_OBJ)"; \
	echo "EXT_ASM=$(EXT_ASM)"; \
	echo "EXT_LIB=$(EXT_LIB)"; \
	echo "EXT_DLL=$(EXT_DLL)"; \
	echo "EXE=$(EXE)"; \
	echo ;\
	echo "OCAML_NATIVE=$(OCAML_NATIVE)"; \
	echo "OCAML_NATIVE_TOOLS=$(OCAML_NATIVE_TOOLS)"; \
	echo "NATDYNLINK=$(NATDYNLINK)"; \
	echo "SUPPORT_SHARED_LIBRARIES=$(SUPPORTS_SHARED_LIBRARIES)"; \
	echo ;\
	echo "PREFIX=$(OCAMLBUILD_PREFIX)"; \
	echo "BINDIR=$(OCAMLBUILD_BINDIR)"; \
	echo "LIBDIR=$(OCAMLBUILD_LIBDIR)"; \
	) > $@

# the configuration file depends on the git environment,
# so it should be rebuilt each time
.PHONY: src/ocamlbuild_config.ml

src/ocamlbuild_config.ml:
	(echo "(* This file was generated from ../configure.make *)"; \
	echo ;\
	echo 'let bindir = "$(OCAMLBUILD_BINDIR)"'; \
	echo 'let libdir = "$(OCAMLBUILD_LIBDIR)"'; \
	echo 'let supports_shared_libraries = $(SUPPORTS_SHARED_LIBRARIES)';\
	echo 'let a = "$(A)"'; \
	echo 'let o = "$(O)"'; \
	echo 'let so = "$(SO)"'; \
	echo 'let ext_dll = "$(EXT_DLL)"'; \
	echo 'let exe = "$(EXE)"'; \
	echo 'let version = "$(VERSION)"'; \
	) > $@
