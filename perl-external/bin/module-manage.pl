#!/usr/bin/env perl

use strict;
use warnings;

use IPC::Run3;
use LWP::Simple;
use File::Slurp;
use Path::Class;
use List::MoreUtils 'uniq';
use CPAN::ParseDistribution;

# TODO - 'updates' action that lists packages that could be updated
# TODO - add smarts to strip out old packages (could switch to building using files.txt after)

my $root_dir               = file(__FILE__)->dir->parent->absolute->stringify;
my $module_list            = "$root_dir/modules.txt";
my $file_list              = "$root_dir/files.txt";
my $minicpan               = "$root_dir/minicpan";
my $local_packages_file    = "$minicpan/modules/02packages.details.txt";
my $local_packages_file_gz = "$local_packages_file.gz";

my %actions = (
    add            => \&add,
    build_all      => \&build_all,
    fetch_all      => \&fetch_all,
    force_install  => \&force_install,
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
  : die("Usage: $0 action [...]\n  actions: "
      . join( ', ', sort keys %actions )
      . "\n" );

exit;

############################################################################

sub init {
    add('App::cpanminus');
}

sub setup {
    fetch_all();
    build('App::cpanminus');
    build_all();
}

sub add {
    my $module = shift || die "Usage: $0 add Dist::To::Add";

    # try to install the distribution using cpanm
    my $out = '';
    my $cmd = "cpanm --reinstall --save-dists $minicpan $module";

    run3( $cmd, undef, undef, undef )
      || die "Error running '$cmd'";

    write_file( $module_list, { append => 1 }, "$module\n" );

    index_minicpan();
    sort_files();
}

sub index_minicpan {

    # Go through all files in minicpan and add to files.txt
    my @files = sort map { s{^.*?(/authors/id/.*)$}{$1}; $_ }
      split '\s', `find $minicpan/authors -type f`;
    write_file( $file_list, map { "$_\n" } @files );

    # work out which ones are not currently in packages
    my @local_packages_lines = read_packages_txt_gz($local_packages_file_gz);

    # Are there any missing files?
    my @missing_files = ();
  MINICPAN_FILE:
    foreach my $file (@files) {
        my ($auth_and_file) = $file =~ m{/authors/id/./../(.*)$};

        foreach my $line (@local_packages_lines) {
            next MINICPAN_FILE if $line =~ m{$auth_and_file};
        }

        push @missing_files, $auth_and_file;
    }

    # If there are no missing files we can stop
    return unless @missing_files;

    # Fetch 02packages off live cpan
    my $remote_packages_url =
      'http://cpan.perl.org/modules/02packages.details.txt.gz';
    my $remote_packages_file = "$minicpan/modules/remote_packages.txt.gz";
    print "  Fetching '$remote_packages_url'...\n";
    is_error( mirror( $remote_packages_url, $remote_packages_file ) )
      && die "Could not retrieve '$remote_packages_url'";
    print "  done...\n";

    my @remote_packages_lines = read_packages_txt_gz($remote_packages_file);

    # Find remaining in live file and add to local file
    my %lines_to_add = ();
    foreach my $missing (@missing_files) {
        print "  Finding matches for '$missing'\n";
        my @matches = grep { m{$missing} } @remote_packages_lines;
        next unless @matches;
        $lines_to_add{$missing} = \@matches;
    }

    # for packages still not found parse out the contents
    foreach my $missing (@missing_files) {
        next if $lines_to_add{$missing};

        print "  Parsing out matches for '$missing'\n";

        my ( $A, $B ) = $missing =~ m{^(.)(.)};
        my $dist =
          CPAN::ParseDistribution->new("$minicpan/authors/id/$A/$A$B/$missing");

        my $modules = $dist->modules();
        my @matches = ();

        foreach my $module ( sort keys %$modules ) {
            my $version = $modules->{$module} || 'undef';

            # Zucchini 0.000017 C/CH/CHISEL/Zucchini-0.0.17.tar.gz
            push @matches, "$module $version $A/$A$B/$missing\n";
        }

        $lines_to_add{$missing} = \@matches;
    }

    # combine and sort the lines found
    my @new_lines = sort @local_packages_lines,
      map { @$_ } values %lines_to_add;
    unlink $local_packages_file_gz;
    write_file( $local_packages_file, map { "$_\n" } packages_file_headers(),
        @new_lines );
    system "gzip -v $local_packages_file";
}

sub read_packages_txt_gz {
    my $file = shift;

    return unless -e $file;

    my @lines = split /\n/, `zcat $file`;

    # ditch the headers
    while ( my $line = shift @lines ) {
        last if $line =~ m{^\s*$};
    }

    return @lines;
}

sub packages_file_headers {

    # this is all fake stuff

    return << 'END_OF_LINES';
Allow-Packages-Only-Once: 0
Columns: package name, version, path
Description: Package names for my private CPAN
File: 02packages.details.txt
Intended-For: My private CPAN
Last-Updated: Wed, 04 May 2011 09:59:13 GMT
Line-Count: 1389
URL: http://example.com/MyCPAN/modules/02packages.details.txt
Written-By: /home/evdb/fixmystreet/perl-external/local-lib/bin/dpan using CPAN::PackageDetails 0.25    

END_OF_LINES
}

sub build_all {
    my @modules = sort uniq map { s{\s+$}{}; $_; } read_file($module_list);
    build($_) for @modules;
}

sub build {
    my $module = shift    #
      || die "Usage: $0 build Module::To::Build\n";

    print "  --- checking/installing $module ---\n";

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
    my @urls = sort uniq map { s{\s+$}{}; $_; } read_file($file_list);
    fetch($_) for @urls;
}

sub fetch {
    my $filename = shift;

    my $destination = file("$minicpan/$filename");
    $destination->dir->mkpath;

    return if -e $destination;

    # create a list of urls to try in order
    my @urls = (
        "http://search.cpan.org/CPAN" . $filename,
        "http://backpan.perl.org" . $filename,
    );

    while ( scalar @urls ) {
        my $url = shift @urls;

        # try to fetch
        print "  Fetching '$url'...\n";
        last if is_success( getstore( $url, "$destination" ) );

        # if more options try again
        next if scalar @urls;

        # could not retrieve - die
        die "ERROR - ran out of urls fetching '$filename'";
    }
}

sub zap {

    # delete all the bits that are generated
    my $local_lib_root = $ENV{PERL_LOCAL_LIB_ROOT} || die;
    dir($local_lib_root)->rmtree(1);
    dir($minicpan)->subdir('authors')->rmtree(1);
}

sub sort_files {
    foreach my $file ( $file_list, $module_list ) {
        my @entries = read_file($file);
        @entries = uniq sort @entries;
        write_file( $file, @entries );
    }
}
