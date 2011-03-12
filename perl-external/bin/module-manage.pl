#!/usr/bin/env perl

use strict;
use warnings;

use IPC::Run3;
use LWP::Simple;
use File::Slurp;
use Path::Class;
use List::MoreUtils 'uniq';

my $root_dir    = file(__FILE__)->dir->parent->absolute->stringify;
my $module_list = "$root_dir/modules.txt";
my $url_list    = "$root_dir/urls.txt";
my $minicpan    = "$root_dir/minicpan";

my %actions = (
    add            => \&add,
    build_all      => \&build_all,
    fetch_all      => \&fetch_all,
    index_minicpan => \&index_minicpan,
    init           => \&init,
    setup          => \&setup,
    sort_files     => \&sort_files,
    zap            => \&zap,
);

# work out what to run
my ( $action, @args ) = @ARGV;
$actions{$action}
  ? $actions{$action}->(@args)
  : die "Usage: $0 action [args ...]\n";

exit;

############################################################################

sub init {
    add('App::cpanminus');
    add('MyCPAN::App::DPAN');
}

sub setup {
    fetch_all();
    build('App::cpanminus');
    build('MyCPAN::App::DPAN');
    build_all();
}

sub add {
    my $module = shift || die "Usage: $0 add Dist::To::Add";

    # try to install the distribution using cpanm
    my $out = '';
    my $cmd = "cpanm --reinstall $module";

    # print "  running '$cmd'\n";
    run3( $cmd, undef, \$out, \$out )
      || die "Error running '$cmd'";

    my @fetched_urls =
      map { s{.*(http://\S+).*}{$1}; $_ }
      grep { m{^Fetching http://search.cpan.org} }
      split /\n/, $out;

    write_file( $module_list, { append => 1 }, "$module\n" );
    write_file( $url_list, { append => 1 }, map { "$_\n" } @fetched_urls );
    sort_files();

    fetch_all();
    index_minicpan();

    if ( $out =~ m{FAIL} ) {
        die "\n\n\n"
          . "ERROR: Something did not build correctly"
          . " - please see ~/.cpanm/build_log for details"
          . "\n\n\n";
    }
}

sub index_minicpan {

    # go to the minicpan dir and run dpan there
    if ( `which dpan` =~ m/\S/ ) {
        chdir $minicpan;
        system "dpan -f ../dpan_config";
    }
    else {
        warn "Skipping indexing - could not find dpan";
    }
}

sub build_all {
    my @modules = sort uniq map { s{\s+$}{}; $_; } read_file($module_list);
    build($_) for @modules;
}

sub build {
    my $module = shift    #
      || die "Usage: $0 build Module::To::Build\n";

    print "  --- installing $module ---\n";

    my $out = '';
    my $cmd = "cpanm --mirror $minicpan --mirror-only  $module";

    # print "  running '$cmd'\n";

    run3( $cmd, undef, \$out, \$out )
      || die "Error running '$cmd'";

    my @lines =
      grep { m{\S} }
      split /\n+/, $out;
    my $last_line = $lines[-1];

    die "Error building '$module':\n\n$last_line\n\n$out\n\n"
      unless $last_line =~ m{Successfully installed }
          || $last_line =~ m{is up to date}
          || $last_line =~ m{\d+ distributions? installed};
}

sub fetch_all {
    my @urls = sort uniq map { s{\s+$}{}; $_; } read_file($url_list);
    fetch($_) for @urls;
}

sub fetch {
    my $url = shift;
    my ($filename) = $url =~ m{/(authors/.+)$};

    my $destination = file("$minicpan/$filename");
    $destination->dir->mkpath;

    return if -e $destination;

    print "  Fetching $url\n";
    print "    -> $destination\n";

    is_success( getstore( $url, "$destination" ) )
      || die "Error saving $url to $destination";
}

sub zap {

    # delete all the bits that are generated
    my $local_lib_root = $ENV{PERL_LOCAL_LIB_ROOT} || die;
    dir($local_lib_root)->rmtree(1);
    dir($minicpan)->subdir('authors')->rmtree(1);
}

sub sort_files {
    foreach my $file ( $url_list, $module_list ) {
        my @entries = read_file($file);
        @entries = uniq sort @entries;
        write_file( $file, @entries );
    }
}
