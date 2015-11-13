unit class _6make is export;

my constant $DIR = $?FILE.IO.parent.abspath;
my constant $ECOSYSTEM =
    'https://raw.githubusercontent.com/perl6/ecosystem/master/META.list';

sub rm(*@files, Bool :$rf) { run 'rm', |($rf ?? '-rf' !! Empty), @files }
sub git(*@args) { run 'git', @args }
sub make(*@targets) { run 'make', @targets }
sub wget($_) { run('wget', '-qO-', $_, :out).out.slurp-rest(:enc<latin1>) }

sub fetch($_) {
    when /^https?\:/ { .&wget }
    default { .IO }
}

sub find(*@paths, :$name, Bool :$f, Bool :$noerr) {
    my $err = $noerr ?? $*SPEC.devnull !! '-';
    run('find', |@paths, |$_, :out, :$err).out.slurp-rest.lines given [
        |($f ?? <-type f> !! Empty),
        |(@$name and
            '\(', |@$name.map({ slip <<-o -name "$_">> }).[1..*], '\)')
    ];
}

sub repos {
    once {
        ENTER my $start = now;
        LEAVE note "loaded repo.list in { (now - $start).round(0.01) }s";
        "$DIR/repo.list".IO.lines.map({ |.comb(/\H+/).[0, 1] }).Hash;
    }
}

sub ecosystem {
    once {
        ENTER my $start = now;
        LEAVE note "parsed eco.list in { (now - $start).round(0.01) }s";
        "$DIR/eco.list".IO.lines.SetHash;
    }
}

sub dump-repos {
    ENTER my $start = now;
    LEAVE note "dumped repo.list in { (now - $start).round(0.01) }s";
    my @keys = repos.keys.sort;
    my $ws = @keys>>.chars.max + 1;
    my $lines = @keys.map({ [~] $_, ' ' x ($ws - .chars), repos{$_}, "\n" });
    "$DIR/repo.list".IO.spurt($lines.join);
}

sub dump-ecosystem {
    ENTER my $start = now;
    LEAVE note "dumped eco.list in { (now - $start).round(0.01) }s";
    "$DIR/eco.list".IO.spurt(ecosystem.keys.map({ "$_\n" }).join);
}

sub parse-meta($key) {
    rx/ '"' $key '"' \h* ':' \h* '"' (<-["]>*) '"' /
}

method nuke { rm :rf, 'blib' }

method get(*@_) {
    for @_ {
        if .IO.d { git '-C', $_, 'pull' }
        else { git 'clone', (repos{$_} // die), $_ }
    }
}

method add($name, $url) {
    my $repo = $name.lc.subst(:g, '::', '-');
    say "normalized name to '$repo'" if $repo ne $name;
    my $former-url = repos{$repo};
    if !defined $former-url {}
    elsif $former-url eq $url {
        say "repository '$repo' is already known under that address";
        return;
    }
    else {
        say "former address was <$former-url>";
        repos{$repo} = $url;
    }

    dump-repos;
    say "added '$repo' to repo.list";
}

method ecosync {
    my @lines = fetch($ECOSYSTEM).lines;
    my @failures;
    my $n = 0;
    my $N = +@lines;
    my $skipped = 0;

    repos, ecosystem;

    for @lines -> $target {
        ++$n;

        if ecosystem{$target}:exists {
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
            ecosystem{$target} = True;
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

    dump-repos;
    dump-ecosystem;
}
