# 6make

Manages and precompiles Perl6 modules via `git` and GNU `make`. It currently
also depends on `find` and `wget`. Dependencies between modules are
auto-detected so precompilation happens in proper order, but missing
dependencies have to be resolved manually.

Example commands for installing `JSON::Tiny`:

```
6make ecosync        # go get some coffee, this takes a while
6make get json-tiny
6make
6make test json-tiny
```

Note that module names are lower-cased, with a single `-` replacing each `::`.

The compiled module files end up in `.blib/`, which can be added to the
`PERL6LIB` environment variable or manually passed via `-I`.

The full list of 6make subcommands is:

```
Usage:
  6make -- an alias for the 'build' subcommand
  6make ecosync -- sync repo.list and eco.list with the ecosystem
  6make list [<strings> ...] -- list repository names matching all <strings>
  6make add <name> <url> -- add repository at <url> as <name>
  6make get [<repos> ...] -- clone or pull repositories via git, then scan
  6make scan -- scan repositories for dependencies
  6make build -- compile modules to bytecode
  6make rebuild -- scan repositories, then compile to bytecode
  6make test [<repos> ...] -- run tests in repositories if available
  6make upgrade -- update all installed repositories and rebuild
  6make nuke -- remove bytecode directory
  6make deps -- dump dependencies for modules in ./lib/ to stdout
```
