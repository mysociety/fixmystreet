use strict; use warnings;
package Open311::Endpoint::Schema::Regex;
use parent 'Data::Rx::CommonType::EasyNew';

use Carp ();

sub type_uri {
    'tag:wiki.open311.org,GeoReport_v2:rx/regex',
}

sub guts_from_arg {
    my ($class, $arg, $rx) = @_;
    $arg ||= {};

    my $pattern = delete $arg->{pattern};
    my $message = delete $arg->{message};
    if (my @unexpected = keys %$arg) {
        Carp::croak sprintf "Unknown arguments %s in constructing %s",
            (join ',' => @unexpected), $class->type_uri;
    }

    return {
        str_schema => $rx->make_schema('//str'),
        pattern => qr/$pattern/,
        message => $message,
    };
}

sub assert_valid {
    my ($self, $value) = @_;

    $self->{str_schema}->assert_valid( $value );

    return 1 if $value =~ $self->{pattern};

    $self->fail({
        error => [ qw(type) ],
        message => $self->{message} || "found value doesn't match regex",
        value => $value,
    })
}

1;
