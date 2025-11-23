package FixMyStreet::App::Controller::Api::MSS;

use Moose;
use namespace::autoclean;
use Open311::GetServiceRequestUpdates;
use DateTime;
use Types::Standard qw(InstanceOf Maybe);
use Try::Tiny;

BEGIN { extends 'FixMyStreet::App::Controller::Api' };

has allowed_cobrands => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    default => sub { ['brent'] }
);

has body => ( is => 'rw', isa => Maybe[InstanceOf['FixMyStreet::DB::Result::Body']] );

sub update : Path('/api/mss/update') : Args(1) {
    my ($self, $c, $moniker) = @_;

    $c->detach('/api/mss/json_response', [404]) unless grep { $_ eq $moniker } @{$self->allowed_cobrands};
    $c->detach('/api/mss/json_response', [405]) unless $c->request->method eq 'POST';

    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker($moniker)->new();
    $self->api_config($cobrand->feature('MSS_api_details'));

    $self->api_password($c->req->header('password'));
    $self->api_username($c->req->header('username'));
    $c->forward('/api/mss/authorise');

    $c->forward('/api/mss/get_json_post_data');
    $c->forward('/api/mss/validate_json_post_data');

    $self->body(FixMyStreet::DB->resultset('Body')->search( { name => $cobrand->council_name } )->first);
    $c->forward('/api/mss/update_reports');

    $c->detach('/api/mss/json_response', [200])
}

sub update_reports : Private {
    my ($self) = @_;

    my $update_request = Open311::GetServiceRequestUpdates->new();
    $update_request->initialise_body($self->body);
    $update_request->process_requests($self->post_data->{updates});
}

sub validate_json_post_data : Private {
    my ($self, $c) = @_;

    $c->detach('/api/mss/json_response', [400]) unless defined $self->post_data->{updates};

    try {
        for my $update (@{$self->post_data->{updates}}) {
            $c->detach unless scalar keys %$update == 5;
            $update->{status} = $self->api_config->{update_status_mapping}->{$update->{external_status_code}};
            FixMyStreet::App::Controller::Api::MSS::Validate::Update->new($update);
        }
    } catch {
        $c->detach('/api/mss/json_response', [400]);
    }
}

return 1;