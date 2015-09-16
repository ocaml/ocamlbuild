#
# Pure OCaml, package from Opam, two directories
#

# - The -I flag introduces sub-directories 
# - -use-ocamlfind is required to find packages (from Opam)
# - _tags file introduces packages, bin_annot flag for tool chain

OCB_FLAGS = -use-ocamlfind -I src -I lib
OCB = 		ocamlbuild $(OCB_FLAGS)

all: 		native byte # profile debug

clean:
			$(OCB) -clean

native: 
			$(OCB) main.native

byte:
			$(OCB) main.byte

profile:
			$(OCB) -tag profile main.native

debug:
			$(OCB) -tag debug main.byte

.PHONY: 	all clean byte native profile debug
