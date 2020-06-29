package FixMyStreet::App::Controller::Waste;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use utf8;
use FixMyStreet::App::Form::Waste::UPRN;

sub auto : Private {
    my ( $self, $c ) = @_;
    my $cobrand_check = $c->cobrand->feature('waste');
    $c->detach( '/page_error_404_not_found' ) if !$cobrand_check;
    return 1;
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    if (my $uprn = $c->get_param('address')) {
        $c->detach('redirect_to_uprn', [ $uprn ]);
    }

    $c->stash->{title} = 'What is your address?';
    my $form = FixMyStreet::App::Form::Waste::UPRN->new( cobrand => $c->cobrand );
    $form->process( params => $c->req->body_params );
    if ($form->validated) {
        my $addresses = $form->value->{postcode};
        $form = address_list_form($addresses);
    }
    $c->stash->{form} = $form;
}

sub address_list_form {
    my $addresses = shift;
    HTML::FormHandler->new(
        field_list => [
            address => {
                required => 1,
                type => 'Select',
                widget => 'RadioGroup',
                label => 'Select an address',
                tags => { last_differs => 1, small => 1 },
                options => $addresses,
            },
            go => {
                type => 'Submit',
                value => 'Continue',
                element_attr => { class => 'govuk-button' },
            },
        ],
    );
}

sub redirect_to_uprn : Private {
    my ($self, $c, $uprn) = @_;
    my $uri = '/waste/uprn/' . $uprn;
    $c->res->redirect($uri);
    $c->detach;
}

sub uprn : Chained('/') : PathPart('waste/uprn') : CaptureArgs(1) {
    my ($self, $c, $uprn) = @_;

    if ($uprn eq 'missing') {
        $c->stash->{template} = 'waste/missing.html';
        $c->detach;
    }

    $c->forward('/auth/get_csrf_token');

    my $property = $c->stash->{property} = $c->cobrand->call_hook(look_up_property => $uprn);
    $c->detach( '/page_error_404_not_found', [] ) unless $property;

    $c->stash->{uprn} = $uprn;
    $c->stash->{latitude} = $property->{latitude};
    $c->stash->{longitude} = $property->{longitude};

    $c->stash->{service_data} = $c->cobrand->call_hook(bin_services_for_address => $property) || [];
    $c->stash->{services} = { map { $_->{service_id} => $_ } @{$c->stash->{service_data}} };
}

sub bin_days : Chained('uprn') : PathPart('') : Args(0) {
    my ($self, $c) = @_;
}

__PACKAGE__->meta->make_immutable;

1;
