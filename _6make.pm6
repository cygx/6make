use nqp;

proto MAIN(|) is export {*}

my constant $DIR = $*PROGRAM.parent.abspath;
my constant $DEVNULL = $*SPEC.devnull;
my constant $ECOSYSTEM =
    'https://raw.githubusercontent.com/perl6/ecosystem/master/META.list';

my class PM {
    has $.name;
    has $.repo;
    has $.path;
    has @.deps;
}

sub wget($_) { run('wget', '-qO-', $_, :out).out.slurp-rest(:enc<latin1>) }

sub fetch($_) {
    when /^https?\:/ { .&wget }
    default { .IO }
}

sub load-repolist($_ = "$DIR/repo.list") {
    ENTER my $start = now;
    LEAVE note "loaded repolist in { round now - $start, .01 }s";
    .IO.lines.map({ |.comb(/\H+/).[0, 1] }).Hash
}

sub load-ecolist($_ = "$DIR/eco.list") {
    ENTER my $start = now;
    LEAVE note "loaded ecolist in { round now - $start, .01 }s";
    .IO.lines.SetHash;
}

sub find-modules($_ = $DIR) {
    ENTER my $start = now;
    LEAVE note "found modules in { round now - $start, .01 }s";

    ENTER my $cwd = $*CWD;
    LEAVE $*CWD = $cwd;
    $*CWD = $_;

    run(< find -name .git -prune -false -o -type f >, :out)\
        .out.slurp-rest.lines.grep(/ '/lib/' .+ \.pm6? $/);
}

sub parse-modules(@files) {
    ENTER my $start = now;
    LEAVE note "parsed modules in { round now - $start, .01 }s";

    my % = @files.map: -> $pm {
        my ($repo, $path) = $pm.split('/lib/', 2);
        my $name = $path.subst(/\.pm6?$/, '').subst(:g, '/', '::');

        my @deps;
        my $fh := nqp::open(nqp::unbox_s("$DIR/$pm"), 'r');
        repeat until nqp::eoffh($fh) {
            $_ := nqp::readlinefh($fh);
            if (not .starts-with('=begin pod') ff .starts-with('=end pod'))
                && /^\h*[use|need]\h+([\w+]+ % '::')/ {
                my $dep := ~$0;
                @deps.push($dep) unless $dep ~~ any
                    BEGIN <v6 nqp MONKEY-TYPING Test NativeCall NQPHLL>;
            }
        }

        $name => PM.new(:$name, :$repo, :$path, :@deps);
    }
}

sub dump-makefile($_ = "$DIR/Makefile", :%pms!, :@missing) {
    ENTER my $start = now;
    LEAVE note "generated Makefile in { (now - $start).round(0.01) }s";

    .IO.spurt: qq:to/__END__/;
BC := { %pms.values>>.path.map({ ".blib/$_.moarvm" }).join(' ') }

bc: \$(BC)
\$(BC):
\t@mkdir -p \$(dir \$@)
\tperl6 -I.blib --target=mbc --output=\$@ \$<

{
    join "\n", do for %pms.values {
        my $pm = $_;
        my $deps = .deps ?? .deps.map({
            if %pms{$_} -> $_ {
                ".blib/{.path}.moarvm";
            }
            else {
                @missing.push(($_, $pm.name));
                '';
            }
        }).join(' ') !! '';

        ".blib/{.path}.moarvm: .blib/\%.moarvm: {.repo}/lib/% $deps";
    }
}
__END__
}

sub dump-repolist($_ = "$DIR/repo.list", :%repos!) {
    ENTER my $start = now;
    LEAVE note "generated repolist in { (now - $start).round(0.01) }s";

    my @keys = %repos.keys.sort;
    my $ws = @keys>>.chars.max + 1;
    my $lines = @keys.map({ [~] $_, ' ' x ($ws - .chars), %repos{$_}, "\n" });
    .IO.spurt($lines.join);
}


sub dump-ecolist($_ = "$DIR/eco.list", :%ecos!) {
    ENTER my $start = now;
    LEAVE note "generated ecolist in { (now - $start).round(0.01) }s";
    .IO.spurt(%ecos.keys.map({ "$_\n" }).join);
}

sub parse-meta($key) {
    rx/ '"' $key '"' \h* ':' \h* '"' (<-["]>*) '"' /
}

sub repos {
    once {
        try open("$DIR/repo.list", :x).?close;
        load-repolist;
    }
}

sub ecos {
    once {
        try open("$DIR/eco.list", :x).?close;
        load-ecolist;
    }
}

sub pms { once parse-modules find-modules }

#| an alias for the 'build' subcommand
multi MAIN { MAIN 'build' }

#| sync repo.list and eco.list with the ecosystem
multi MAIN('ecosync') {
    my @lines = fetch($ECOSYSTEM).lines;
    my @failures;
    my $n = 0;
    my $N = +@lines;
    my $skipped = 0;

    repos, ecos;

    for @lines.grep(/\S/) -> $target {
        ++$n;
        if ecos{$target}:exists {
            ++$skipped;
            next;
        }
        my ($name, $url);
        for fetch($target).lines {
            $name = ~$0 if (BEGIN parse-meta 'name');
            $url = ~$0 if (BEGIN parse-meta 'source-url');
        }
        if $name && $url {
            my $repo = $name.lc.subst(:g, '::', '-');
            say "    $n/$N $name => $repo";
            repos{$repo} = $url;
            ecos{$target} = True;
        }
        else {
            @failures.push($target);
            say "X $target";
        }
    }
    say '';
    say "skipped $skipped already known entries"
        if $skipped;
    if @failures {
        say "the following entries failed to parse:";
        .say for @failures;
    }
    dump-repolist(repos => repos);
    dump-ecolist(ecos => ecos);
}

#| list repository names matching all <strings>
multi MAIN('list', *@strings) {
    SEARCH: for repos.keys -> $name {
        $name.index(.lc) // SEARCH.next for @strings;
        say "  $name", "$DIR/$name".IO.d ?? ' [ INSTALLED ]' !! '';
    }
}

#| add repository at <url> as <name>
multi MAIN('add', Str $name, Str $url) {
    my $repo = $name.lc.subst(:g, '::', '-');
    say "normalized name to '$repo'" if $repo ne $name;
    my $former-url = repos{$repo};

    if !defined $former-url {
        repos{$repo} = $url;
    }
    elsif $former-url eq $url {
        say "repository '$repo' is already known under that address";
        return;
    }
    else {
        say "former address was <$former-url>";
        repos{$repo} = $url;
    }

    dump-repolist :repos(repos);
    say "repository '$repo' has been added";
}

#| clone or pull repositories via git, then scan
multi MAIN('get', *@repos) {
    for @repos {
        my $path = "$DIR/$_";
        if $path.IO.d { run 'git', '-C', $path, 'pull' }
        else {
            if repos{$_}:exists {
                run 'git', 'clone', repos{$_}, $path;
            }
            else {
                say "cannot clone unknown repository '$_'";
            }
        }
    }

    MAIN 'scan'
}

#| scan repositories for dependencies
multi MAIN('scan') {
    my @missing;
    dump-makefile :pms(pms), :@missing;
    for @missing {
        say "missing dependency {.[0]} for {.[1]}"
    }
}

#| compile modules to bytecode
multi MAIN('build') { run 'make', '-C', $DIR, '--no-print-directory' }

#| scan repositories, then compile to bytecode
multi MAIN('rebuild') {
    MAIN 'scan';
    MAIN 'build';
}

#| run tests in repositories if available
multi MAIN('test', *@repos) {
    for @repos {
        unless "$DIR/$_/t".IO.d {
            say "'$_' does not have tests";
            next;
        }

        shell "cd $DIR/$_ && prove -r -e \"perl6 -I../.blib\" t/";
    }
}

#| update all installed repositories and rebuild
multi MAIN('upgrade') {
    for repos.keys {
        my $path = "$DIR/$_";
        if $path.IO.d {
            say "-- $_:";
            run 'git', '-C', $path, 'pull'
        }
    }

    MAIN 'rebuild';
}

#| remove bytecode directory
multi MAIN('nuke') { run 'rm', '-rf', "$DIR/.blib/" }
