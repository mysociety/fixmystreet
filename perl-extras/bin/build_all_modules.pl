#!/usr/bin/env perl

use strict;
use warnings;

use IPC::Run3;
use LWP::Simple;
use YAML;
use File::Slurp;
use Path::Class;

my $root_dir    = file(__FILE__)->dir->parent->absolute->stringify;
my $module_list = "$root_dir/modules.txt";
my $minicpan    = "$root_dir/minicpan";
my $local_lib   = "$root_dir/../local-lib5";
my $cpanm_cmd =
  "perl $root_dir/bin/cpanm --mirror $minicpan --mirror-only -l $local_lib";

my @modules = map { s{\s+$}{}; $_; } read_file($module_list);

foreach my $module (@modules) {
    print "  --- installing $module ---\n";

    my $out = '';
    my $cmd = "$cpanm_cmd $module";

    print "  running '$cmd'\n";

    run3( $cmd, undef, \$out, \$out )
      || die "Error running '$cmd'";

    my @lines =
      grep { m{\S} }
      split /\n+/, $out;
    my $last_line = $lines[-1];

    die "Error building '$module':\n\n$out\n\n"
      unless $last_line =~ m{Successfully installed }
          || $last_line =~ m{is up to date};
}
