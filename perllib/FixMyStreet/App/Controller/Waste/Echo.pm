package FixMyStreet::App::Controller::Waste::Echo;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

with 'FixMyStreet::Roles::Syslog';

use utf8;
use Open311::GetServiceRequestUpdates;

has log_ident => (
    is => 'ro',
    default => sub {
        my $feature = 'echo';
        my $features = FixMyStreet->config('COBRAND_FEATURES');
        return unless $features && ref $features eq 'HASH';
        return unless $features->{$feature} && ref $features->{$feature} eq 'HASH';
        my $f = $features->{$feature}->{_fallback};
        return $f->{log_ident};
    }
);

sub receive_echo_event_notification : Path('/waste/echo') : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{format} = 'xml';
    $c->response->header(Content_Type => 'application/soap+xml');

    require SOAP::Lite;

    $c->detach('soap_error', [ 'Invalid method', 405 ]) unless $c->req->method eq 'POST';

    my $echo = $c->cobrand->feature('echo');
    $c->detach('soap_error', [ 'Missing config', 500 ]) unless $echo;

    # Make sure we log entire request for debugging
    $c->detach('soap_error', [ 'Missing body' ]) unless $c->req->body;
    my $soap = join('', $c->req->body->getlines);
    $self->log($soap);

    my $body = $c->cobrand->body;
    $c->detach('soap_error', [ 'Bad jurisdiction' ]) unless $body;

    my $env = SOAP::Deserializer->deserialize($soap);

    my $header = $env->header;
    $c->detach('soap_error', [ 'Missing SOAP header' ]) unless $header;
    my $action = $header->{Action};
    $c->detach('soap_error', [ 'Incorrect Action' ]) unless $action && $action eq $echo->{receive_action};
    $header = $header->{Security};
    $c->detach('soap_error', [ 'Missing Security header' ]) unless $header;

    my $token = $header->{UsernameToken};
    $c->detach('soap_error', [ 'Authentication failed' ])
        unless $token && $token->{Username} eq $echo->{receive_username};

    my $passwords = $echo->{receive_password};
    $passwords = [ $passwords ] unless ref $passwords eq 'ARRAY';
    my $password_match;
    foreach (@$passwords) {
        $password_match = 1 if $_ eq $token->{Password};
    }
    $c->detach('soap_error', [ 'Authentication failed' ]) unless $password_match;

    my $event = $env->result;

    # Return okay if we're in endpoint test mode
    my $cobrand_check = $c->cobrand->feature('waste');
    $c->detach('soap_ok') if $cobrand_check eq 'echo-push-only';

    my $cfg = { echo => Integrations::Echo->new(%$echo) };
    my $request = $c->cobrand->construct_waste_open311_update($cfg, $event);
    $c->detach('soap_ok') if !$request->{status} || $request->{status} eq 'confirmed'; # Ignore new events

    $request->{updated_datetime} = DateTime::Format::W3CDTF->format_datetime(DateTime->now);
    if ($c->cobrand->moniker eq 'brent') {
        $request->{service_request_id} = "Echo-" . $event->{Guid};
    } else {
        $request->{service_request_id} = $event->{Guid};
    }
    my $ref = $event->{ClientReference} || '';
    if (my ($fms_id) = $ref =~ /^[A-Z]*-(.*)$/) {
        $request->{fixmystreet_id} = $fms_id;
    }

    my @bodies = ($body);
    if ($c->cobrand->moniker eq 'kingston') {
        my $sutton = FixMyStreet::Cobrand::Sutton->new->body;
        push @bodies, $sutton;
    }

    foreach my $b (@bodies) {
        my $suppress_alerts = $event->{EventTypeId} == 1159 ? 1 : 0;
        my $updates = Open311::GetServiceRequestUpdates->new(
            system_user => $b->comment_user,
            current_body => $b,
            suppress_alerts => $suppress_alerts,
        );
        my $p = $updates->find_problem($request);
        if ($p) {
            $c->forward('check_existing_update', [ $p, $request, $updates ]);

            # If a bulky collection hasn't been paid, do not
            # send alerts on any updates that come in
            if ($p->category eq 'Bulky collection'
                && $c->cobrand->bulky_send_before_payment
                && !$p->get_extra_metadata('payment_reference')
                && !$p->get_extra_metadata('chequeReference')) {
                $updates->suppress_alerts(1);
            }

            my $comment = $updates->process_update($request, $p);
            last;
        }
    }

    # Still want to say it is okay, even if we did nothing with it
    $c->forward('soap_ok');
}

sub soap_error : Private {
    my ($self, $c, $comment, $code) = @_;
    $code ||= 400;
    $c->response->status($code);
    my $type = $code == 500 ? 'Server' : 'Client';
    $c->response->body(SOAP::Serializer->fault($type, "Bad request: $comment", soap_header()));
}

sub soap_ok : Private {
    my ($self, $c) = @_;
    $c->response->status(200);
    my $method = SOAP::Data->name("NotifyEventUpdatedResponse")->attr({
        xmlns => "http://www.twistedfish.com/xmlns/echo/api/v1"
    });
    $c->response->body(SOAP::Serializer->envelope(method => $method, soap_header()));
}

sub soap_header {
    my $attr = "http://www.twistedfish.com/xmlns/echo/api/v1";
    my $action = "NotifyEventUpdatedResponse";
    my $header = SOAP::Header->name("Action")->attr({
        xmlns => 'http://www.w3.org/2005/08/addressing',
        'soap:mustUnderstand' => 1,
    })->value("$attr/ReceiverService/$action");

    my $dt = DateTime->now();
    my $dt2 = $dt->clone->add(minutes => 5);
    my $w3c = DateTime::Format::W3CDTF->new;
    my $header2 = SOAP::Header->name("Security")->attr({
        'soap:mustUnderstand' => 'true',
        'xmlns' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'
    })->value(
        \SOAP::Header->name(
            "Timestamp" => \SOAP::Header->value(
                SOAP::Header->name('Created', $w3c->format_datetime($dt)),
                SOAP::Header->name('Expires', $w3c->format_datetime($dt2)),
            )
        )->attr({
            xmlns => "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd",
        })
    );
    return ($header, $header2);
}

sub check_existing_update : Private {
    my ($self, $c, $p, $request, $updates) = @_;

    my $cfg = { updates => $updates };
    $c->detach('soap_ok')
        unless $c->cobrand->waste_check_last_update(
            'push', $cfg, $p, $request->{status}, $request->{external_status_code});
}

__PACKAGE__->meta->make_immutable;

1;
