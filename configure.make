# This file serve as a ./configure file, written as a GNU Makefile.
# It generates a local Makefile.config file that will be included by
# the main Makefile.

# Note: we initially included `ocamlc -where`/Makefile.config directly
# from the main Makefile, but this made it not robust to addition of
# new variables to this ocaml/Makefile.config that we do not control.

OCAML_LIBDIR = $(shell ocamlc -where)
include $(OCAML_LIBDIR)/Makefile.config

OCAML_PREFIX = $(prefix)
OCAML_MANDIR = $(MANDIR)

# If you want to affect ocamlbuild's configuration by passing variable
# assignments to this Makefile, you probably want to define those
# OCAMLBUILD_* variables.

OCAMLBUILD_PREFIX ?= $(OCAML_PREFIX)
OCAMLBUILD_BINDIR ?= \
  $(or $(shell opam config var bin 2>/dev/null),\
       $(OCAML_PREFIX)/bin)
OCAMLBUILD_LIBDIR ?= \
  $(or $(shell opam config var lib 2>/dev/null),\
       $(shell ocamlfind printconf destdir 2>/dev/null),\
       $(OCAML_LIBDIR))
OCAMLBUILD_MANDIR ?= \
  $(or $(shell opam config var man 2>/dev/null),\
       $(OCAML_MANDIR))

# OCAMLBUILD_RELOCATABLE is true if:
#   1. The compiler is Relocatable OCaml
#   2. ocamlbuild will be installed in the same directory as the compiler
#   3. OCAMLBUILD_LIBDIR is an explicit relative path (i.e. begins ./ or ../)
# OCAMLBUILD_RELOCATABLE is empty if any of these things are not true.
OCAMLBUILD_LIBDIR_RELATIVE = $(filter . .. ./% ../%, $(OCAMLBUILD_LIBDIR))
OCAML_RELOCATABLE = \
  $(shell ocamlc -config-var standard_library_relative 2>/dev/null)
OCAMLC_BIN_DIR = $(abspath $(dir $(shell command -v ocamlc)))
# On Windows, OCAMLC_BIN_DIR will be a Cygwin-style path but OCAMLBUILD_BINDIR
# is a native path. The requirement is that OCAMLBUILD_BINDIR needs to be the
# same as the compiler - that means it _must_ already exist, so it gets
# canonicalised using "poor man's realpath" by doing cd+pwd.
OCAMLBUILD_BINDIR_RESOLVED = $(shell cd '$(OCAMLBUILD_BINDIR)' 2>/dev/null ; pwd)
OCAMLBUILD_RELOCATABLE := \
  $(if $(OCAMLBUILD_LIBDIR_RELATIVE),$\
    $(if $(OCAML_RELOCATABLE),$\
      $(if $(filter $(abspath $(OCAMLBUILD_BINDIR_RESOLVED)),$(OCAMLC_BIN_DIR)),true)))

# If OCAMLBUILD_LIBDIR is an explicit relative path, but Relocatable ocamlbuild
# cannot be built (see above), then OCAMLBUILD_LIBDIR_ACTUAL is the absolute
# path calculated by concatenating OCAML_LIBDIR and OCAMLBUILD_LIBDIR. Otherwise
# it is just OCAMLBUILD_LIBDIR.
OCAMLBUILD_LIBDIR_ACTUAL := \
  $(if $(OCAMLBUILD_RELOCATABLE),$(OCAMLBUILD_LIBDIR),$\
    $(if $(OCAMLBUILD_LIBDIR_RELATIVE),$\
      $(if $(filter .., $(OCAMLBUILD_LIBDIR)),$(dir $(OCAML_LIBDIR)),$\
        $(abspath $(OCAML_LIBDIR)/$(OCAMLBUILD_LIBDIR)),$(OCAMLBUILD_LIBDIR))))

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
# OCAMLBUILD_{PREFIX,{BIN,LIB,MAN}DIR}, which are the ones that should
# generally be used, as the shorter names PREFIX,{BIN,LIB,MAN}DIR.

ifeq ($(ARCH), none)
OCAML_NATIVE ?= false
else
OCAML_NATIVE ?= true
endif

OCAML_NATIVE_TOOLS ?= $(OCAML_NATIVE)

all: Makefile.config src/ocamlbuild_config.ml

clean:

distclean:
	rm -f Makefile.config src/ocamlbuild_config.ml

Makefile.config:
	(echo "# This file was generated from configure.make"; \
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
	echo "OCB_EXTRA_LINKFLAGS=$(OCB_EXTRA_LINKFLAGS)"; \
	echo ;\
	echo "PREFIX=$(OCAMLBUILD_PREFIX)"; \
	echo "BINDIR=$(OCAMLBUILD_BINDIR)"; \
	echo "LIBDIR=$(OCAMLBUILD_LIBDIR_ACTUAL)"; \
	echo "MANDIR=$(OCAMLBUILD_MANDIR)"; \
	) > $@

ifeq ($(OCAMLBUILD_RELOCATABLE), true)

# For Relocatable ocamlbuild, just record the relative path specified for
# OCAMLBUILD_LIBDIR and the current directory name (".") for BINDIR and the
# extra code apppended from src/ocamlbuild_config.ml.in will process the correct
# values at runtime.
src/ocamlbuild_config.ml: BINDIR = .
src/ocamlbuild_config.ml: OCAML_LIBDIR =
src/ocamlbuild_config.ml: LIBDIR_ABS =

OCB_EXTRA_LINKFLAGS = \
  -set-runtime-default standard_library_default=$(OCAML_RELOCATABLE)

else

# For normal ocamlbuild, record the configured values.
src/ocamlbuild_config.ml: BINDIR := $(OCAMLBUILD_BINDIR)
src/ocamlbuild_config.ml: OCAML_LIBDIR := $(abspath $(OCAML_LIBDIR))
src/ocamlbuild_config.ml: LIBDIR_ABS := $(abspath $(OCAMLBUILD_LIBDIR_ACTUAL))

OCB_EXTRA_LINKFLAGS =

endif

src/ocamlbuild_config.ml: src/ocamlbuild_config.ml.in
	(echo "(* This file was generated from ../configure.make *)"; \
	echo ;\
	echo 'let bindir = {|$(BINDIR)|}'; \
	echo 'let libdir = {|$(OCAMLBUILD_LIBDIR_ACTUAL)|}'; \
	echo 'let ocaml_libdir = {|$(OCAML_LIBDIR)|}'; \
	echo 'let libdir_abs = {|$(LIBDIR_ABS)|}'; \
	echo 'let ocaml_native = $(OCAML_NATIVE)'; \
	echo 'let ocaml_native_tools = $(OCAML_NATIVE_TOOLS)'; \
	echo 'let supports_shared_libraries = $(SUPPORTS_SHARED_LIBRARIES)';\
	echo 'let a = "$(A)"'; \
	echo 'let o = "$(O)"'; \
	echo 'let so = "$(SO)"'; \
	echo 'let ext_dll = "$(EXT_DLL)"'; \
	echo 'let exe = "$(EXE)"'; \
	echo 'let version = "$(shell ocaml scripts/cat.ml VERSION)"'; \
	$(if $(OCAMLBUILD_RELOCATABLE),cat src/ocamlbuild_config.ml.in;) \
	) > $@
