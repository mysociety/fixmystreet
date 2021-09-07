package FixMyStreet::Roles::Open311Multi;
use Moo::Role;

=head1 NAME

FixMyStreet::Roles::Open311Multi - role for adding Open311 things specific to an open311-adapter Multi integration

=cut

# Multi integrations need to be passed the service code as part of update sending

around open311_munge_update_params => sub {
    my ($orig, $self, $params, $comment, $body) = @_;

    $self->$orig($params, $comment, $body);

    my $contact = $comment->problem->contact; 
    $params->{service_code} = $contact->email; 
};

1;
