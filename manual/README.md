This [manual in progress](manual.md) is an effort to replace the
[current OCamlbuild
manual](http://caml.inria.fr/pub/docs/manual-ocaml/ocamlbuild.html)
with something that satisfies users better.

The present documentation is currently only a draft, with parts
missing. Contributions are warmly welcome to evolve into a more
polished and complete document.


## Angles of improvement

The not-good-enough documentation is a subject that often comes up in
ocamlbuild discussions. It's surprisingly hard to get feedback on what
should be improved, but here is what I heard:

- there are not enough short examples to reuse/tweak and forget about
- a clear presentation of the basic mental model of the tool is missing
- writing a `myocamlbuild.ml` is frightening and little help is
  provided (though the former
  wiki, whose content is now on [ocaml.org](http://ocaml.org/learn/tutorials/ocamlbuild/), does
  answer questions)

I would add two points:

- There is too much blatter about design philosophies that aren't
  terribly helpful in the end

- The manual doesn't emphasize enough the combination of ocamlbuild
  and ocamlfind, as the latter tool was not a given when ocamlbuild
  was designed. Choosing ocamlbuild+ocamlfind as the default tool
  combination allows a simpler presentation that does more by default
  and skips over some less-useful features (`use_foo` and
  non-ocamlfind camlp4 stuff).


## Integrating the wiki content

The former wiki, whose content is now on [ocaml.org](http://ocaml.org/learn/tutorials/ocamlbuild/), has
a lot of valuable information, but for a mix of social and technical
reasons it hasn't evolved into a good alternate documentation that
I could point beginners to. Hopefully using git will feel cooler than
wikisyntax did to potential contributors -- I even decided to ignore my
worries and go for the priorietary github platform to lower barrier to
entry.

You can help by integrating [ocaml.org](http://ocaml.org/learn/tutorials/ocamlbuild/) content in the present documentation.


## Feedback needed

It is *very* hard to write good documentations, and so far I have no
idea whether what's current there is better or worse than the
manual. Tell me!

You can use the issue-tracker to comments on precise or general
"defects" of the present document (things that are missing and must be
present, or things that are here but should be shortened, or things
for which you would like to change the presentation). A patch is even
more useful than a bug report.

For less precise comments (or to send patches), you can send an email
at (gabriel dot scherer at the more-and-more-evil google mail).
