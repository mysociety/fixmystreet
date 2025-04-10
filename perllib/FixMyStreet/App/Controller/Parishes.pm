package FixMyStreet::App::Controller::Parishes;
use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::App::Controller::Form' }

use utf8;
use FixMyStreet::App::Form::Parishes;

has feature => (
    is => 'ro',
    default => 'parishes'
);

has form_class => (
    is => 'ro',
    default => 'FixMyStreet::App::Form::Parishes',
);

has index_template => (
    is => 'ro',
    default => 'parishes/index.html',
);


sub process_parish : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;

    ::Dwarn $data;

    # TODO Store details somewhere (but not create the body, haven't got payment, unless we add an "unconfirmed" state to bodies...?)
    # TODO Redirect to payment
}

sub pay_complete : Path('pay_complete') : Args(2) {
    my ($self, $c, $id, $token) = @_;

    # TODO Check ID/token
    # TODO Check payment
    # TODO Success
    #   Store subscription ID on user? or body?
    # TODO Failure
    # TODO Send to admin for approval
}

sub admin : Local {
    my ($self, $c) = @_;

    $c->detach('/auth/redirect') unless $c->user_exists;

    $c->stash->{template} = 'parishes/admin/index.html';
    # TODO - if superuser, show parishes requiring approval
    # FixMyStreet::Parishes::set_up_parish(Name, MapIt ID, Categories, User)
    # TODO - if parish staff user, show admin interface - pages will be categories / (templates) / invoices
        # link to Stripe management page Customer Portal Session
}

sub redirect_to_stripe_customer_portal {
    # TODO
}

__PACKAGE__->meta->make_immutable;

1;
