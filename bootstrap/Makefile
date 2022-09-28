OCAMLBUILD ?= ocamlbuild

all: stage2

setup:
	$(MAKE) -C .. clean
	$(MAKE) -C .. src/ocamlbuild_config.ml
	ln -sf ../src
	ln -sf ../bin
	ln -sf ../plugin-lib
	mkdir -p dest

stage1: setup
	@echo "BOOTSTRAP (1): building local ocamlbuild from '$(OCAMLBUILD)'"
	@$(OCAMLBUILD) -build-dir _build_stage1 bootstrap.otarget

stage2: stage1
	@echo "BOOTSTRAP (2): building local ocamlbuild from local ocamlbuild"
	@_build_stage1/bin/ocamlbuild.native -build-dir _build_stage2 bootstrap.otarget

clean:
	@$(OCAMLBUILD) -clean
	@$(OCAMLBUILD) -build-dir _build_stage1 -clean
	@$(OCAMLBUILD) -build-dir _build_stage2 -clean
	@rm -f src bin plugin-lib
	@rm -f dest/ocamlbuild_{stage1,stage2}.native
	@rmdir dest

