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

sub receive_whitespace_event_notification : Path('/waste/whitespace') : Args(0) {
    my ($self, $c) = @_;

    require SOAP::Lite;

    $c->detach('/waste/echo/soap_error', [ 'Invalid method', 405 ]) unless $c->req->method eq 'POST';

    my $whitespace = $c->cobrand->feature('whitespace');
    $c->detach('/waste/echo/soap_error', [ 'Missing config', 500 ]) unless $whitespace;

    $c->detach('/waste/echo/soap_error', [ 'Missing body' ]) unless $c->req->body;
    my $soap = join('', $c->req->body->getlines);
    $self->log($soap);

    my $body = $c->cobrand->body;
    $c->detach('soap_error', [ 'Bad jurisdiction' ]) unless $body;

    my $env = SOAP::Deserializer->deserialize($soap);
    if ($env->valueof('//WorksheetPoke/secret') ne $whitespace->{push_secret}) {
        return $c->detach('/waste/echo/soap_error', [ 'Unauthorized', 401 ]);
    };

    # Return okay if we're in endpoint test mode
    my $cobrand_check = $c->cobrand->feature('waste');
    $c->detach('soap_ok') if $cobrand_check eq 'echo-push-only';

    my $worksheet = {
        id => $env->valueof('//WorksheetPoke/worksheetId'),
        ref => $env->valueof('//WorksheetPoke/worksheetReference'),
        completed => $env->valueof('//WorksheetPoke/completedDate'),
    };
    $c->detach('/waste/echo/soap_error', [ 'Bad request', 400 ]) if _check_params($worksheet);

    $c->forward('update_report', [ $worksheet ]);
    $c->forward('soap_ok');
}

sub soap_ok : Private {
    my ($self, $c) = @_;
    $c->response->status(200);
    $c->response->body('OK');
}

sub update_report : Private {
    my ($self, $c, $worksheet) = @_;

    my $request = $c->cobrand->construct_waste_open311_update({}, $worksheet);
    return if !$request->{status} || $request->{status} eq 'confirmed';

    my $report = delete $request->{report};
    return unless $report;

    $request->{comment_time} =
        DateTime::Format::W3CDTF->parse_datetime($worksheet->{completed})
            ->set_time_zone(FixMyStreet->local_time_zone);

    my $body = $c->cobrand->body;
    my $updates = Open311::GetServiceRequestUpdates->new(
        current_body => $body,
        system_user => $body->comment_user
    );

    return unless $c->cobrand->waste_check_last_update({}, $report, $request->{status});
    $updates->process_update($request, $report);
}

sub _check_params {
    my $hash = shift;

    for my $key (keys %{$hash}) {
        return 1 unless $hash->{$key};
    }
}

1;
