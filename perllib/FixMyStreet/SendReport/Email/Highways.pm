package FixMyStreet::SendReport::Email::Highways;

use Moo;
extends 'FixMyStreet::SendReport::Email';

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;

    return unless @{$self->bodies} == 1;
    my $body = $self->bodies->[0];

    my $contact = $self->fetch_category($body, $row) or return;
    my $email = $contact->email;
    my $area_name = $row->get_extra_field_value('area_name') || '';
    my $area_email = FixMyStreet->config('COBRAND_FEATURES') || {};
    $area_email = $area_email->{open311_email}->{highwaysengland}->{$area_name};
    $email = $area_email if $area_email;

    @{$self->to} = map { [ $_, $body->name ] } split /,/, $email;
    return 1;
}

1;
