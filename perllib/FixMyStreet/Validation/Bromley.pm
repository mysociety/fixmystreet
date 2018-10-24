package FixMyStreet::Validation::Bromley;

use Moo;

has body => (
    is => 'ro',
    default => 'Bromley',
);

sub validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->detail ) > 1750 ) {
        $errors->{detail} = sprintf( _('Reports are limited to %s characters in length. Please shorten your report'), 1750 );
    }

    return $errors;
}

1;
