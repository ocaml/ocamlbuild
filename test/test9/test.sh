#########################################################################
#                                                                       #
#                                 OCaml                                 #
#                                                                       #
#   Nicolas Pouillard, Berke Durak, projet Gallium, INRIA Rocquencourt  #
#                                                                       #
#   Copyright 2007 Institut National de Recherche en Informatique et    #
#   en Automatique.  All rights reserved.  This file is distributed     #
#   under the terms of the Q Public License version 1.0.                #
#                                                                       #
#########################################################################

#!/bin/sh
set -e
set -x
cd `dirname $0`/../..
if [ "$OCB" = "ocamlbuild" ]; then
    set -- '-I' "$($OCB -where | tr -d '\r')"
else
    set -- '-I' 'src' '-I' 'plugin-lib'
fi
ocamlc "$@" -I +unix unix.cma ocamlbuildlib.cma test/test9/testglob.ml -o ./testglob.native
./testglob.native
rm testglob.native
