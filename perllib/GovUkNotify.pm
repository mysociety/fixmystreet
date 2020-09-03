package GovUkNotify;

use Crypt::JWT;
use JSON::MaybeXS;
use LWP::UserAgent;
use Moo;

# The GOV.UK Notify API key, in full
has key => ( is => 'ro', required => 1 );

# The Notify template ID to be used. It should be "((text))" so can be any text
# that we set (but you could include a footer or something, watch out for
# length)
has template_id => ( is => 'ro', required => 1 );

# This can be set to a Notify ID to be used as the sender
has sms_sender_id => ( is => 'ro' );

has base => ( is => 'ro', default => 'https://api.notifications.service.gov.uk' );

has token => ( is => 'lazy', default => sub {
    my $self = shift;

    my ($iss, $secret) = $self->key =~ /^.+?-(.{36})-(.+)$/;

    my $payload = {
        iss => $iss,
        iat => time(),
    };

    return Crypt::JWT::encode_jwt(
        payload => $payload,
        alg => 'HS256',
        key => $secret,
    );
});

# Given to, body and optional ref as a hash, sends an SMS through GOV.UK Notify
sub send {
    my ($self, %params) = @_;

    my $request = {
        phone_number => $params{to},
        template_id => $self->template_id,
        personalisation => {
            text => $params{body},
        }
    };
    $request->{reference} = $params{ref} if $params{ref};
    $request->{sms_sender_id} = $self->sms_sender_id if $self->sms_sender_id;

    my $ua = LWP::UserAgent->new;
    my $response = $ua->post(
        $self->base . '/v2/notifications/sms',
        Authorization => 'Bearer ' . $self->token,
        Content_Type => 'application/json',
        Content => encode_json($request),
    );

    return {
        code => $response->code,
        content => $response->decoded_content,
    };
}

1;
