package FixMyStreet::Validation::Rutland;

use Moo;

has body => (
    is => 'ro',
    default => 'Rutland',
);

sub validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->name ) > 40 ) {
        $errors->{name} = sprintf( _('Names are limited to %d characters in length.'), 40 );
    }

    return $errors;
}

1;
