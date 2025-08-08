package FixMyStreet::App::Form::Field::Postcode;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Text';

use mySociety::PostcodeUtil;

apply(
    [
        {
            transform => sub {
                my ( $value, $field ) = @_;
                $value =~ s/[^A-Z0-9]//ig;
                return mySociety::PostcodeUtil::canonicalise_postcode($value);
            }
        },
        {
            check => sub { mySociety::PostcodeUtil::is_valid_postcode(shift) },
            message => 'Sorry, we did not recognise that postcode.',
        }
    ]
);


__PACKAGE__->meta->make_immutable;
use namespace::autoclean;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

FixMyStreet::App::Form::Field::Postcode - validates postcode using mySociety::PostcodeUtil

=head1 DESCRIPTION

Validates that the input looks like a postcode using L<mySociety::PostcodeUtil>.
Widget type is 'text'.

=head1 DEPENDENCIES

L<mySociety::PostcodeUtil>

=cut

