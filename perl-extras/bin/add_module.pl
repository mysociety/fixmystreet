#!/usr/bin/env perl

use strict;
use warnings;

use IPC::Run3;
use LWP::Simple;
use YAML;
use File::Slurp;

my $cpan_meta_db_base = "http://cpanmetadb.appspot.com/v1.0/package";
my $cpan_mirror_base  = "http://search.cpan.org/CPAN/authors/id";
my $root_dir          = "/home/evdb/fixmystreet/perl-extras";
my $dist_list         = "$root_dir/install_order.txt";
my $dist_dir          = "$root_dir/distributions";
my $local_lib_dir     = "local-lib5";
my $fake_mirror       = "$root_dir/fake_mirror";
my $cpanm_cmd         = "perl $root_dir/cpanm --reinstall -L $local_lib_dir";

# my $cpanm_cmd =
#   "perl $dist_dir/cpanm --mirror $fake_mirror --mirror-only -L $local_lib_dir";

my $module = $ARGV[0] || die "Usage: $0 Dist::To::Add";

# try to install the distribution using cpanm
my $out = '';
my $cmd = "$cpanm_cmd $module";
print "  running '$cmd'\n";
run3( $cmd, undef, \$out, \$out )
  || die "Error running '$cmd'";

warn $out;

my @fetched_urls =
  map { s{.*(http://\S+).*}{$1}; $_ }
  grep { m{^Fetching http://search.cpan.org} }
  split /\n/, $out;

my @installed =
  grep { $_ }
  map { m{^Successfully (?:re)?installed (\S+).*} ? $1 : undef }
  split /\n/, $out;

use Data::Dumper;
local $Data::Dumper::Sortkeys = 1;
warn Dumper( { fetched => \@fetched_urls, installed => \@installed } );

foreach my $dist (@installed) {
    my ($url) = grep { m{/$dist\.} } @fetched_urls;
    my ($filename) = $url =~ m{([^/]+)$};

    print "  getting $filename from $url\n";

    is_success( getstore( $url, "$dist_dir/$filename" ) )
      || die "Error saving $url to $dist_dir/$filename";
    write_file( $dist_list, { append => 1 }, "$filename\n" );
}

# #
# # load list of modules at start and write it back at the end
# my %installed = ();
# my %looked_at = ();
#
# sub add_filename_to_list {
#     my $module = shift;
#     print "Adding '$module' to '$dist_list'\n";
#     append( $dist_list, "$module\n" );
#     getc;
# }
#
# # add_module('App::cpanminus');
# add_module($module_to_add);
#
# sub add_module {
#     my $module = shift;
#     print "--- $module ---\n";
#     return 1 if $installed{$module} || $looked_at{$module}++;
#
#     # get the distribution this module is in
#     my $yaml = get("$cpan_meta_db_base/$module")
#       || die "Can't get details from $cpan_meta_db_base/$module";
#     my $dist_info = Load($yaml);
#     my $distfile  = $dist_info->{distfile}
#       || die("Can't get distfile from returned YAML for $module");
#
#     # fetch the distribution from cpan
#     my ($filename) = $distfile =~ m{/([^/]*)$};
#     unless ( -e "$dist_dir/$filename" ) {
#         my $dist_url = "$cpan_mirror_base/$distfile";
#         print "  fetching '$dist_url' to '$dist_dir/$filename'\n";
#         is_success( getstore( $dist_url, "$dist_dir/$filename" ) )
#           || die "Could not fetch $dist_url";
#     }
#
#     # try to install the distribution using cpanm
#     my $out = '';
#     my $cmd = "$cpanm_cmd $dist_dir/$filename";
#     print "  running '$cmd'\n";
#     run3( $cmd, undef, \$out, \$out ) || die "Error running '$cmd'";
#
#     warn "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n";
#     warn $out;
#     warn "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n";
#
#     my @missing_modules =
#       map { s{^.*\s(\S+)$}{$1}; $_ }
#       grep { m/Couldn\'t find module or a distribution/ }
#       split /\n/, $out;
#
#     if ( scalar @missing_modules ) {
#         print "  missing: ", join( ', ', @missing_modules ), "\n";
#         add_module($_) for @missing_modules;
#         add_module($module);
#     }
#     elsif ( $out =~ m{Successfully installed } ) {
#
#         # add ourselves to the done lists
#         print "  Success with '$filename'\n";
#         $installed{$module}++;
#         add_filename_to_list($filename);
#     }
#     else {
#         die "No success and no missing modules for $module";
#     }
#
# }
#
# #
