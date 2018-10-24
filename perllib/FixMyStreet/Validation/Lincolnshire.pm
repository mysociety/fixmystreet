package FixMyStreet::Validation::Lincolnshire;

use Moo;

has body => (
    is => 'ro',
    default => 'Lincolnshire',
);

sub validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->user->phone ) > 20 ) {
        $errors->{phone} = sprintf( _('Phone numbers are limited to %s characters in length.'), 20 );
    }

    return $errors;
}

1;
