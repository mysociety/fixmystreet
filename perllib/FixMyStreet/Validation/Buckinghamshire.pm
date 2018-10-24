package FixMyStreet::Validation::Buckinghamshire;

use Moo;

has body => (
    is => 'ro',
    default => 'Buckinghamshire',
);

sub validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->name ) > 50 ) {
        $errors->{name} = sprintf( _('Names are limited to %d characters in length.'), 50 );
    }

    return $errors;
}

1;
