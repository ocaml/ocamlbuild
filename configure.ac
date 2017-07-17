#                                               -*- Autoconf -*-
dnl Process this file with autoconf to produce a configure script.

AC_PREREQ([2.62])
AC_INIT([ocamlbuild],[0.12.0],[https://github.com/ocaml/ocamlbuild/issues])
AC_CONFIG_SRCDIR([src/main.ml])
AC_CONFIG_AUX_DIR([conf-aux])
AM_INIT_AUTOMAKE([foreign subdir-objects -Wno-portability])
AC_ARG_ENABLE([check_if_preinstalled],
              [AS_HELP_STRING([--enable-check_if_preinstalled],
                              [Check if it is preinstalled.])])
AC_ARG_ENABLE([use_native_OCaml_tools],
              [AS_HELP_STRING([--enable-use_native_OCaml_tools],
                              [Use native tools for OCaml.])])
AC_SUBST([CHECK_IF_PREINSTALLED],[${enable_check_if_preinstalled}])
AC_SUBST([OCAML_NATIVE_TOOLS],[${enable_use_native_OCaml_tools}])
AC_ARG_VAR([ARCH],[Computer architecture])
AC_ARG_VAR([OCAML_PREFIX],[Prefix directory for OCaml])
AC_ARG_VAR([OCAML_BINDIR],[Directory for OCaml binary files])
AC_ARG_VAR([OCAML_LIBDIR],[Directory for OCaml library files])
AC_ARG_VAR([OCAML_MANDIR],[Directory for OCaml files of the manual])
AC_ARG_VAR([A],[Suffix for library code])
AC_ARG_VAR([O],[Suffix for object code])
AC_ARG_VAR([SO],[Suffix for shared object code])
AC_ARG_VAR([EXT_OBJ],[Suffix for object files])
AC_ARG_VAR([EXT_ASM],[Suffix for assembler files])
AC_ARG_VAR([EXT_LIB],[Suffix for library files])
AC_ARG_VAR([EXT_DLL],[Suffix for dynamic link library files])
AC_ARG_VAR([EXE],[Suffix for executable code])
AC_ARG_VAR([NATDYNLINK],[Activation for native dynamic linking (true/false)])
AC_ARG_VAR([SUPPORTS_SHARED_LIBRARIES],[Indication for the support of shared libraries (true/false)])
AC_SUBST([protect],[""])
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MKDIR_P
AC_CONFIG_FILES([GNUmakefile])
AC_OUTPUT
