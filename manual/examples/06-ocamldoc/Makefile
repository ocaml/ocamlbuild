#
# Pure OCaml, no packages, no _tags, code in serveral directories
# Targets starting with "doc_" generate documentation for the Util and Hello
# modules
#

# bin-annot is required for Merlin and other IDE-like tools
# The -I flag introduces sub-directories to search for code

OCB_FLAGS = -tag bin_annot -I src -I lib
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

doc_html:
			$(OCB) doc/api.docdir/index.html

doc_man:
			$(OCB) doc/api.docdir/man

doc_tex:
# the name of the .tex file can be anything
			$(OCB) doc/api.docdir/api.tex

doc_texinfo:
# the name of the .texi file can be anything
			$(OCB) doc/api.docdir/api.texi

doc_dot:
# the .dot graph represents inter-module dependencies
# as before, the name doesn't matter
			$(OCB) doc/api.docdir/api.dot

test: 		native
			./main.native "OCaml" "OCamlBuild" "users"


.PHONY: 	all clean byte native profile debug test
