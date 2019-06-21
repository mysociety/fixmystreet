package FixMyStreet::SendReport::Email::SingleBodyOnly;

use Moo;
extends 'FixMyStreet::SendReport::Email';

has contact => (
    is => 'ro',
    default => sub { die 'Need to override contact' }
);

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;

    return unless @{$self->bodies} == 1;
    my $body = $self->bodies->[0];

    # We don't care what the category was, look up the relevant contact
    my $contact = $self->fetch_category($body, $row, $self->contact) or return;

    @{$self->to} = map { [ $_, $body->name ] } split /,/, $contact->email;
    return 1;
}

1;
