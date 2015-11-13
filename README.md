# 6make

Precompiles Perl6 modules via GNU `make`. It currently also depends on `find`
and `wget`.

Example commands for installing `JSON::Tiny`:

```
./6make ecosync
./6make scan

make json-tiny 6
```

Dependencies have to be resolved manually.

Builtin make targets:

```
6       -- rescan installed repositories and compile bytecode to blib/
bc      -- compile bytecode as necessary, but don't rescan [DEFAULT TARGET]
scan    -- rescan installed repostories, but don't compile
pull    -- git pull every installed repository
clean   -- nuke blib/
```
