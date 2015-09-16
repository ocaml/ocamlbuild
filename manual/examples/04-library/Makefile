#
# Pure OCaml, package from Opam, two directories
#

# - The -I flag introduces sub-directories 
# - -use-ocamlfind is required to find packages (from Opam)
# - _tags file introduces packages, bin_annot

OCB_FLAGS = -use-ocamlfind -I src -I libdemo
OCB = 		ocamlbuild $(OCB_FLAGS)

all: 		native byte lib # profile debug

clean:
			$(OCB) -clean

lib:
			$(OCB) libdemo.cma
			$(OCB) libdemo.cmxa
			$(OCB) libdemo.cmxs

native: 
			$(OCB) main.native

byte:
			$(OCB) main.byte

profile:
			$(OCB) -tag profile main.native

debug:
			$(OCB) -tag debug main.byte

.PHONY: 	all clean byte native profile debug lib
