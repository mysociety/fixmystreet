package FixMyStreet;

use strict;
use warnings;

use Path::Class;
my $ROOT_DIR = file(__FILE__)->parent->parent->absolute->resolve;

use Readonly;

use mySociety::Config;

# load the config file and store the contents in a readonly hash
mySociety::Config::set_file( __PACKAGE__->path_to("conf/general") );
Readonly::Hash my %CONFIG, %{ mySociety::Config::get_list() };

=head1 NAME

FixMyStreet

=head1 DESCRIPTION

FixMyStreet is a webite where you can report issues and have them routed to the
correct authority so that they can be fixed.

Thus module has utility functions for the FMS project.

=head1 METHODS

=head2 path_to

    $path = FixMyStreet->path_to( 'conf/general' );

Returns an absolute Path::Class object representing the path to the arguments in
the FixMyStreet directory.

=cut

sub path_to {
    my $class = shift;
    return $ROOT_DIR->file(@_);
}

=head2 config

    my $config_hash_ref = FixMyStreet->config();
    my $config_value    = FixMyStreet->config($key);

Returns a hashref to the config values. This is readonly so any attempt to
change it will fail.

Or you can pass it a key and it will return the value for that key, or undef if
it can't find it.

=cut

sub config {
    my $class = shift;
    return \%CONFIG unless scalar @_;

    my $key = shift;
    return exists $CONFIG{$key} ? $CONFIG{$key} : undef;
}

1;
