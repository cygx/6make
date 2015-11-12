# 6make

Precompiles Perl6 modules via GNU `make`. It currently also depends on `find`
and `wget`.

Example commands for installing `JSON::Tiny`:

```
./6make ecosync
./6make scan

make json-tiny 6 bc
```

Dependencies have to be resolved manually.

Builtin make targets:

```
6       -- rescan installed repositories for dependencies
bc      -- compile bytecode as necessary into blib/ [DEFAULT TARGET]
pull    -- git pull every installed repository
clean   -- nuke blib/
upgrade -- alias for `make pull 6 bc`
```
