#!/usr/bin/env perl

use strict;
use warnings;

use IPC::Run3;
use LWP::Simple;
use File::Slurp;
use Path::Class;

my $root_dir    = file(__FILE__)->dir->parent->absolute->stringify;
my $module_list = "$root_dir/modules.txt";
my $url_list    = "$root_dir/urls.txt";
my $minicpan    = "$root_dir/minicpan";
my $local_lib   = "$root_dir/../local-lib5";
my $cpanm_cmd   = "perl $root_dir/bin/cpanm -l $local_lib --reinstall";

my $module = $ARGV[0] || die "Usage: $0 Dist::To::Add";

# try to install the distribution using cpanm
my $out = '';
my $cmd = "$cpanm_cmd $module";
print "  running '$cmd'\n";
run3( $cmd, undef, \$out, \$out )
  || die "Error running '$cmd'";

my @fetched_urls =
  map { s{.*(http://\S+).*}{$1}; $_ }
  grep { m{^Fetching http://search.cpan.org} }
  split /\n/, $out;

write_file( $module_list, { append => 1 }, "$module\n" );
write_file( $url_list, { append => 1 }, map { "$_\n" } @fetched_urls );

foreach my $url ( read_file($url_list) ) {

    my ($filename) = $url =~ m{/(authors/.+)$};

    my $destination = file("$minicpan/$filename");
    $destination->dir->mkpath;

    next if -e $destination;

    print "  $url\n    -> $destination\n";

    is_success( getstore( $url, "$destination" ) )
      || die "Error saving $url to $destination";
}

# go to the minicpan dir and run dpan there
chdir $minicpan;
exec 'dpan -f ../dpan_config';
