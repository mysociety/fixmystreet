package FixMyStreet;

use strict;
use warnings;

use Path::Class;
my $ROOT_DIR = file(__FILE__)->parent->parent->absolute->resolve;

use DateTime::TimeZone;
use Readonly;
use Sub::Override;

use mySociety::Config;
use mySociety::DBHandle;

my $CONF_FILE = $ENV{FMS_OVERRIDE_CONFIG} || 'general';

# load the config file and store the contents in a readonly hash
mySociety::Config::set_file( __PACKAGE__->path_to("conf/${CONF_FILE}") );
Readonly::Hash my %CONFIG, %{ mySociety::Config::get_list() };

=head1 NAME

FixMyStreet

=head1 DESCRIPTION

FixMyStreet is a webite where you can report issues and have them routed to the
correct authority so that they can be fixed.

Thus module has utility functions for the FMS project.

=head1 METHODS

=head2 test_mode

    FixMyStreet->test_mode( $bool );
    my $in_test_mode_bool = FixMyStreet->test_mode;

Put the FixMyStreet into test mode - intended for the unit tests:

    BEGIN {
        use FixMyStreet;
        FixMyStreet->test_mode(1);
    }

=cut

my $TEST_MODE = undef;

sub test_mode {
    my $class = shift;
    $TEST_MODE = shift if scalar @_;
    return $TEST_MODE;
}

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

sub override_config($&) {
    my $config = shift;
    my $code = \&{shift @_};

    mySociety::MaPit::configure($config->{MAPIT_URL}) if $config->{MAPIT_URL};

    # NB: though we have this, templates tend to use [% c.config %].
    # This overriding happens after $c->config is set, so note that
    # FixMyStreet::App->setup_request rewrites $c->config if we are in
    # test_mode, so tests should Just Work there too.

    my $override_guard = Sub::Override->new(
        "FixMyStreet::config",
        sub {
            my ($class, $key) = @_;
            return { %CONFIG, %$config } unless $key;
            return $config->{$key} if exists $config->{$key};
            my $orig_config = mySociety::Config::load_default();
            return $orig_config->{$key} if exists $orig_config->{$key};
        }
    );

    FixMyStreet::Map::reload_allowed_maps() if $config->{MAP_TYPE};

    $code->();

    $override_guard->restore();
    mySociety::MaPit::configure() if $config->{MAPIT_URL};
    FixMyStreet::Map::reload_allowed_maps() if $config->{MAP_TYPE};
}

=head2 dbic_connect_info

    $connect_info = FixMyStreet->dbic_connect_info;

Returns the array that DBIx::Class::Schema needs to connect to the database.
Most of the values are read from the config file and others are hordcoded here.

=cut

# for exact details on what this could return refer to:
#
# http://search.cpan.org/dist/DBIx-Class/lib/DBIx/Class/Storage/DBI.pm#connect_info
#
# we use the one that is most similar to DBI's connect.

# FIXME - should we just use mySociety::DBHandle? will that lead to AutoCommit
# woes (we want it on, it sets it to off)?

sub dbic_connect_info {
    my $class  = shift;
    my $config = $class->config;

    my $dsn = "dbi:Pg:dbname=" . $config->{FMS_DB_NAME};
    $dsn .= ";host=$config->{FMS_DB_HOST}"
      if $config->{FMS_DB_HOST};
    $dsn .= ";port=$config->{FMS_DB_PORT}"
      if $config->{FMS_DB_PORT};
    $dsn .= ";sslmode=allow";

    my $user     = $config->{FMS_DB_USER} || undef;
    my $password = $config->{FMS_DB_PASS} || undef;

    my $dbi_args = {
        AutoCommit     => 1,
        pg_enable_utf8 => 1,
    };
    my $dbic_args = {};

    return ( $dsn, $user, $password, $dbi_args, $dbic_args );
}

=head2 configure_mysociety_dbhandle

    FixMyStreet->configure_mysociety_dbhandle();

Calls configure in mySociety::DBHandle with args from the config. We need to do
this so that old code that uses mySociety::DBHandle finds it properly set up. We
can't (might not) be able to share the handle as DBIx::Class wants it with
AutoCommit on (so that its transaction code can be used in preference to calling
begin and commit manually) and mySociety::* code does not.

This should be fixed/standardized to avoid having two database handles floating
around.

=cut

sub configure_mysociety_dbhandle {
    my $class  = shift;
    my $config = $class->config;

    mySociety::DBHandle::configure(
        Name     => $config->{FMS_DB_NAME},
        User     => $config->{FMS_DB_USER},
        Password => $config->{FMS_DB_PASS},
        Host     => $config->{FMS_DB_HOST} || undef,
        Port     => $config->{FMS_DB_PORT} || undef,
    );

}

my $tz;
my $tz_f;

sub local_time_zone {
    $tz //= DateTime::TimeZone->new( name => "local" );
    return $tz;
}

sub time_zone {
    $tz_f //= DateTime::TimeZone->new( name => FixMyStreet->config('TIME_ZONE') )
        if FixMyStreet->config('TIME_ZONE');
    return $tz_f;
}

sub set_time_zone {
    my ($class, $dt)  = @_;
    my $tz = local_time_zone();
    my $tz_f = time_zone();
    $dt->set_time_zone($tz);
    $dt->set_time_zone($tz_f) if $tz_f;
}

# Development functions

sub staging_flag {
    my ($cls, $flag, $value) = @_;
    $value = 1 unless defined $value;
    return unless $cls->config('STAGING_SITE');
    my $flags = $cls->config('STAGING_FLAGS');
    unless ($flags && ref $flags eq 'HASH') {
        # Assume all flags 0 if missing
        return !$value;
    }
    return $flags->{$flag} == $value;
}

1;
