package FixMyStreet::Roles::ConfirmValidation;
use Moo::Role;

=head1 NAME

FixMyStreet::Roles::ConfirmValidation - role for adding standard confirm validation

=head1 SYNOPSIS

This is applied to a Cobrand class to add validation of reports using standard
Confirm field lengths.

    use Moo;
    with 'FixMyStreet::Roles::ConfirmValidation';

=cut

has max_report_length => ( is => 'ro', default => 2000 );

sub report_validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->name ) > 50 ) {
        $errors->{name} = sprintf( _('Names are limited to %d characters in length.'), 50 );
    }

    if ( length( $report->user->phone ) > 20 ) {
        $errors->{phone} = sprintf( _('Phone numbers are limited to %s characters in length.'), 20 );
    }

    if ( length( $report->detail ) > $self->max_report_length ) {
        $errors->{detail} = sprintf( _('Reports are limited to %s characters in length. Please shorten your report'), $self->max_report_length );
    }

    return $errors;
}

1;
