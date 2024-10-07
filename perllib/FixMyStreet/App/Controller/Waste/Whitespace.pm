package FixMyStreet::App::Controller::Waste::Whitespace;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

with 'FixMyStreet::Roles::Syslog';

use utf8;

has log_ident => (
    is => 'ro',
    default => sub {
        my $feature = 'whitespace';
        my $features = FixMyStreet->config('COBRAND_FEATURES');
        return unless $features && ref $features eq 'HASH';
        return unless $features->{$feature} && ref $features->{$feature} eq 'HASH';
        my $f = $features->{$feature}->{_fallback};
        return $f->{log_ident};
    }
);

has whitespace_config => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} }
);

sub receive_whitespace_event_notification : Path('/waste/whitespace') : Args(0) {
    my ($self, $c) = @_;

    require SOAP::Lite;

    $c->detach('/waste/echo/soap_error', [ 'Invalid method', 405 ]) unless $c->req->method eq 'POST';

    my $whitespace = $c->cobrand->feature('whitespace');
    $self->whitespace_config($whitespace);
    $c->detach('/waste/echo/soap_error', [ 'Missing config', 500 ]) unless $whitespace;

    $c->detach('/waste/echo/soap_error', [ 'Missing body' ]) unless $c->req->body;
    my $soap = join('', $c->req->body->getlines);
    $self->log($soap);

    my $body = $c->cobrand->body;
    $c->detach('soap_error', [ 'Bad jurisdiction' ]) unless $body;

    my $env = SOAP::Deserializer->deserialize($soap);
    if ($env->valueof('//WorksheetPoke/secret') ne $self->whitespace_config->{missed_collection_secret}) {
        return $c->detach('/waste/echo/soap_error', [ 'Unauthorized', 401 ]);
    };

    # Return okay if we're in endpoint test mode
    my $cobrand_check = $c->cobrand->feature('waste');
    $c->detach('soap_ok') if $cobrand_check eq 'echo-push-only';

    my %params;
    $params{external_id} = $env->valueof('//WorksheetPoke/worksheetId');
    $params{status} = $env->valueof('//WorksheetPoke/status');
    $params{completed} = $env->valueof('//WorksheetPoke/completedDate');
    $params{update_ref} = $env->valueof('//WorksheetPoke/worksheetReference');

    return $c->detach('/waste/echo/soap_error', [ 'Bad request', 400 ]) if _check_params(\%params);
    return $c->detach('/waste/echo/soap_error', [ 'Bad request', 400 ]) unless grep { $_ eq $params{status} } keys %{$self->whitespace_config->{missed_collection_state_mapping}};
    $c->forward('update_report', [ \%params ]);

    $c->forward('soap_ok');
}

sub soap_ok : Private {
    my ($self, $c) = @_;
    $c->response->status(200);
    $c->response->body('OK');
}

sub update_report : Private {
    my ($self, $c, $params) = @_;

    my $request = $c->cobrand->construct_waste_open311_update($self->whitespace_config, $params);
    $c->detach('soap_ok') if !$request->{status} || $request->{status} eq 'confirmed';

    $request->{updated_datetime} = $params->{completed};
    $request->{service_request_id} = "Whitespace-" . $params->{external_id};
    if ($params->{update_ref}) {
        $request->{fixmystreet_id} = $params->{update_ref};
    }

    my $body = $c->cobrand->body;
    my $updates = Open311::GetServiceRequestUpdates->new(
        current_body => $body,
        system_user => $body->comment_user
    );

    my $report = $updates->find_problem($request);
    if ($report) {
        my $status_hash = $self->whitespace_config->{missed_collection_state_mapping}{$params->{status}};
        return unless $c->cobrand->waste_check_last_update({}, $report, $status_hash);
        $updates->process_update($request, $report);
    }
}

sub _check_params {
    my $hash = shift;

    for my $key (keys %{$hash}) {
        return 1 unless $hash->{$key};
    }
}

1;
