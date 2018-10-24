package FixMyStreet::Validation::Oxfordshire;

use Moo;

has body => (
    is => 'ro',
    default => 'Oxfordshire',
);

sub validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->detail ) > 1700 ) {
        $errors->{detail} = sprintf( _('Reports are limited to %s characters in length. Please shorten your report'), 1700 );
    }

    return $errors;
}

1;
