# 6make

Precompiles Perl6 modules via GNU `make`. It currently also depends on `find`
and `wget`.

Example commands for installing `JSON::Tiny`:

```
./6make ecosync
./6make scan

make json-tiny 6
make t-json-tiny
```

Dependencies have to be resolved manually.

Builtin make targets:

```
6        -- rescan installed repositories and compile bytecode to blib/
bc       -- compile bytecode as necessary, but don't rescan [DEFAULT TARGET]
scan     -- rescan installed repostories, but don't compile
pull     -- git pull every installed repository
clean    -- nuke blib/
fulltest -- run tests of all installed modules
```

Additionally, each module comes with the following set of targets:

```
name-of-module      -- git clone the repository if necessary
pull-name-of-module -- git pull an already cloned repository
t-name-of-module    -- run tests in module's t/ directory if present

```

All module names are lower-case, with a single `-` replacing each `::`.

In addition to the Makefile, there's also `6make` with following usage:

```
Usage:
  ./6make scan
  ./6make add [<METAINFO> ...]
  ./6make --batch add <LIST>
  ./6make ecosync
```

The `scan` subcommand needs to be run manually once to generate the Makefile.
After that, you'll normally use it indirectly via `make scan` and `make 6`.

The `add` subcommand expects a list of paths or URLs to Perl6 `META.info` or
`META6.json` files, scanning them for `name` and `source-url` entries to add
to `repo.list`.

If `--batch` is passed, the list is taken from a file instead of the argument
list.

The `ecosync` subcommand batch adds the whole *modules.perl6.org* `META.list`.
