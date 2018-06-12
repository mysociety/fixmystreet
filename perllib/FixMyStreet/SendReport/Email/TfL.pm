package FixMyStreet::SendReport::Email::TfL;

use Moo;
extends 'FixMyStreet::SendReport::Email';

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;

    return unless @{$self->bodies} == 1;
    my $body = $self->bodies->[0];

    # We don't care what the category was, look up the Traffic lights contact
    my $contact = $row->result_source->schema->resultset("Contact")->not_deleted->find({
        body_id => $body->id,
        category => 'Traffic lights',
    });
    return unless $contact;

    @{$self->to} = map { [ $_, $body->name ] } split /,/, $contact->email;
    return 1;
}

1;
