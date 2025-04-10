package FixMyStreet::App::Controller::Parishes;
use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::App::Controller::Form' }

use utf8;
use JSON::MaybeXS;
use Integrations::Stripe;
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

has stripe => ( is => 'rw' );

sub auto : Private {
    my ($self, $c) = @_;
    $self->stripe(
        Integrations::Stripe->new(
            config => ($c->cobrand->feature('stripe') || {}),
        )
    );
    $self->next::method($c);
}

sub existing :Local {
    my ($self, $c) = @_;

    my $body = $c->get_param('body');
    $body = FixMyStreet::DB->resultset("Body")->find($body);
    $c->detach('detach_index') unless $body;
    $c->stash->{body} = $body;
}

sub process_parish : Private {
    my ($self, $c, $form) = @_;
    my $data = $form->saved_data;
    my $cfg = $self->stripe->config;

    my $parish_name = $form->c->stash->{label_for_field}($form, 'parish', $data->{parish});

    my $body = FixMyStreet::DB->resultset("Body")->new({
        name => $parish_name,
        deleted => 1,
    });
    $body->set_extra_metadata( logo => $data->{logo} ) if $data->{logo};
    $body->insert;
    $body->body_areas->create({ area_id => $data->{parish} });

    my $user = FixMyStreet::DB->resultset("User")->find_or_create({ email => $data->{email} });
    $user->name($data->{name});
    $user->from_body($body->id);
    $user->update;

    foreach (@{$data->{categories}}) {
        my $contact = FixMyStreet::DB->resultset("Contact")->new({
            body_id => $body->id,
            category => $_->{name},
            email => $data->{email},
            state => 'confirmed',
            note => 'Adding via parishes form',
            whenedited => \'current_timestamp',
            editor => 'Parishes',
        });
        $contact->set_extra_metadata( prefer_if_multiple => 1 );
        $contact->insert;
    }

    my $extra = FixMyStreet::DB->resultset("Config")->find('extra_parishes');
    if ($extra) {
        $extra->update({
            value => \[ "value || ?", '"' . $data->{parish} . '"' ],
        });
    } else {
        FixMyStreet::DB->resultset("Config")->set(extra_parishes => [$data->{parish}]);
    }

    my $session = $self->stripe->request(POST => 'checkout/sessions', {
        success_url => $c->uri_for_action('/parishes/pay_complete') . '?session={CHECKOUT_SESSION_ID}',
        #cancel_url='https://example.com/canceled.html',
        allow_promotion_codes => 'true',
        mode => 'subscription',
        'line_items[0][price]' => $cfg->{price_id},
        'line_items[0][quantity]' => 1,
        'customer_email' => $data->{email},
        'subscription_data[default_tax_rates][0]' => $cfg->{tax_rate},
        'subscription_data[metadata][parish]' => $parish_name,
    });
    if ($session->{error}) {
        # Oh dear
    }
    $c->res->redirect($session->{url});
    $c->detach;
}

sub pay_complete : Path('pay_complete') : Args(0) {
    my ($self, $c) = @_;

    my $session_id = $c->get_param('session');

    my $session = $self->stripe->request(GET => "checkout/sessions/$session_id", { 'expand[]' => 'customer' });
    if ($session->{error}) {
        $c->stash->{error} = $session->{error};
        $c->detach;
    }
    my $email = $session->{customer}{email};
    my $user = FixMyStreet::DB->resultset("User")->find({ email => $email });
    my $body = $user->from_body;

    $body->set_extra_metadata( parish_subscription => $session->{subscription} );
    $body->update;

    $c->stash->{body} = $body;
    $c->stash->{user} = $user;
    # $c->send_email();
}

sub admin : Local {
    my ($self, $c) = @_;

    $c->detach('/auth/redirect') unless $c->user_exists;

    $c->stash->{template} = 'parishes/admin/index.html';

    if ($c->user->is_superuser) {
        $c->stash->{parishes} = [ FixMyStreet::DB->resultset("Body")->search({
            extra => { '\?', 'parish_subscription' },
        })->all ];
    }

    my $body;
    if ($c->user->is_superuser) {
        if (my $id = $c->get_param('parish')) {
            $body = FixMyStreet::DB->resultset("Body")->find($id);
        }
    } elsif ($c->user->from_body) {
        $body = $c->user->from_body;
    } else {
        $c->detach('detach_index');
    }

    if ($body) {
        my $sub_id = $body->get_extra_metadata('parish_subscription');
        $c->detach('detach_index') if !$sub_id;
        $c->stash->{body} = $body;
    }
}

sub stripe_portal :Local {
    my ($self, $c) = @_;

    $c->detach('detach_index') unless $c->user_exists;

    my $body;
    if ($c->user->is_superuser) {
        $body = FixMyStreet::DB->resultset("Body")->find($c->get_param('parish'));
    } else {
        $body = $c->user->from_body;
    }
    $c->detach('detach_index') unless $body;
    my $sub_id = $body->get_extra_metadata('parish_subscription');
    my $sub = $self->stripe->request(GET => "subscriptions/$sub_id");
    my $customer = $sub->{customer};
    my $session = $self->stripe->request(POST => 'billing_portal/sessions', {
        return_url => $c->uri_for_action('parishes/admin'),
        customer => $customer,
    });
    $c->res->redirect($session->{url});
    $c->detach;
}

sub detach_index :Private {
    my ($self, $c) = @_;
    $c->res->redirect('/parishes');
}

__PACKAGE__->meta->make_immutable;

1;
