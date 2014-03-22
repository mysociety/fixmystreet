use strict; use warnings;
package Open311::Endpoint::Schema::DateTime;
use parent 'Data::Rx::CommonType::EasyNew';

use Carp ();

sub type_uri {
    'tag:wiki.open311.org,GeoReport_v2:rx/datetime',
}

sub guts_from_arg {
    my ($class, $arg, $rx) = @_;
    $arg ||= {};

    if (my @unexpected = keys %$arg) {
        Carp::croak sprintf "Unknown arguments %s in constructing %s",
            (join ',' => @unexpected), $class->type_uri;
    }

    return {
        str_schema => $rx->make_schema('//str'),
    };
}

sub assert_valid {
    my ($self, $value) = @_;

    $self->{str_schema}->assert_valid( $value );

    return 1 if $value =~ m{
        ^
        \d {4} # yyyy
      - \d {2} # mm
      - \d {2} # dd
        T
        \d {2} # hh
      : \d {2} # mm
      : \d {2} # ss
       (?:
            Z        # "Zulu" time, e.g. UTC
        |   [+-]     # +/- offset
            \d {2} # hh
          : \d {2} # mm
       )
       $
    }ax; # use ascii semantics so /d means [0-9], and allow formatting

    $self->fail({
        error => [ qw(type) ],
        message => 'found value is not a datetime',
        value => $value,
    })
}

1;
