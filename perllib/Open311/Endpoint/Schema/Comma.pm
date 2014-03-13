use strict; use warnings;
package Open311::Endpoint::Schema::Comma;
use parent 'Data::Rx::CommonType::EasyNew';

use Carp ();

sub type_uri {
    'tag:wiki.open311.org,GeoReport_v2:rx/comma',
}

sub guts_from_arg {
    my ($class, $arg, $rx) = @_;
    $arg ||= {};

    my $contents = delete $arg->{contents}
        or Carp::croak "No contents for comma-separated list";
    my $trim = delete $arg->{trim};
    if (my @unexpected = keys %$arg) {
        Carp::croak sprintf "Unknown arguments %s in constructing %s",
            (join ',' => @unexpected), $class->type_uri;
    }

    return {
        trim => $trim,
        str_schema => $rx->make_schema('//str'),
        subschema => $rx->make_schema( $contents ),
    };
}

sub assert_valid {
    my ($self, $value) = @_;

    $self->{str_schema}->assert_valid( $value );

    my @values = split ',' => $value;

    my $subschema = $self->{subschema};
    my $trim = $self->{trim};

    for my $subvalue (@values) {

        if ($self->{trim}) {
            $subvalue =~s/^\s*//;
            $subvalue =~s/\s*$//;
        }

        $subschema->assert_valid( $subvalue );
    }

    return 1;
}

1;
