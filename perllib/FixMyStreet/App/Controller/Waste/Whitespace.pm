package FixMyStreet::App::Controller::Waste::Whitespace;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

with 'FixMyStreet::Roles::Syslog';

use utf8;

require SOAP::Lite;

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

    $c->detach('soap_error', [ 'Invalid method', 405 ]) unless $c->req->method eq 'POST';

    $self->whitespace_config(FixMyStreet->config('COBRAND_FEATURES')->{whitespace}{bexley});

    my %headers = $c->req->headers->flatten;
    $self->log($c->req->method);
    $self->log(\%headers);
    $self->log($c->req->parameters);
    if ($c->req->body) {
        my $soap = join('', $c->req->body->getlines);
        $self->log($soap);
        my $env = SOAP::Deserializer->deserialize($soap);
        if ($env->valueof('//WorksheetPoke/secret') ne $self->whitespace_config->{missed_collection_secret}) {
            return $c->detach('soap_error', [ 'Unauthorized', 401 ]);
        };
        my %params;
        $params{external_id} = $env->valueof('//WorksheetPoke/worksheetId');
        $params{status} = $env->valueof('//WorksheetPoke/status');
        $params{completed_dt} = $env->valueof('//WorksheetPoke/completedDate');
        $params{update_ref} = $env->valueof('//WorksheetPoke/status');
        return $c->detach('soap_error', [ 'Bad request', 400 ]) if _check_params(\%params);
        $self->update_report(\%params);
    } else {
        $self->log('No body');
        return $c->detach('soap_error', [ 'Bad request', 400 ]);
    }

    $c->response->status(200);
    $c->response->body('OK');
}

sub update_report {
    my ($self, $params) = @_;

    my $report = FixMyStreet::DB->resultset("Problem")->search( { external_id => 'Whitespace-' . $params->{external_id} } )->first;
    return unless $report;

    my $status_hash = $self->whitespace_config->{missed_collection_state_mapping}{$params->{status}};
    return unless $self->waste_check_last_update($report, $status_hash);

    my $request = {
        description => $status_hash->{text},
        comment_time => $params->{completed_dt},
        external_status_code => $params->{update_ref},
        prefer_template      => 1,
        status               => $status_hash->{fms_state},
        # TODO Is there an ID for specific worksheet update?
        update_id => $report->external_id,
    };

    my $body = FixMyStreet::DB->resultset('Body')->find( { name => 'London Borough of Bexley' } );

    Open311::GetServiceRequestUpdates->new(
        current_body => $body,
        system_user => $body->comment_user
    )->process_update(
        $request,
        $report
    );
}

sub waste_check_last_update {
    my ( $self, $report, $new_state ) = @_;

    my $last_update = $report->comments->search(
        { external_id => { like => 'Whitespace%' } },
    )->order_by('-id')->first;

    if ( $last_update && $new_state->{fms_state} eq $last_update->problem_state ) {
        return;
    }

    return 1;
}

sub _check_params {
    my $hash = shift;

    for my $key (keys %{$hash}) {
        return 1 unless $hash->{$key};
    }
}

1;
