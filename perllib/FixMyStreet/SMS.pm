package FixMyStreet::SMS;

use strict;
use warnings;

use JSON::MaybeXS;
use Moo;
use Number::Phone::Lib;
use WWW::Twilio::API;

use FixMyStreet;
use mySociety::EmailUtil qw(is_valid_email);
use FixMyStreet::DB;

has twilio => (
    is => 'lazy',
    default => sub {
        WWW::Twilio::API->new(
            AccountSid => FixMyStreet->config('TWILIO_ACCOUNT_SID'),
            AuthToken => FixMyStreet->config('TWILIO_AUTH_TOKEN'),
            utf8 => 1,
        );
    },
);

has from => (
    is => 'lazy',
    default => sub { FixMyStreet->config('TWILIO_FROM_PARAMETER') },
);

has messaging_service => (
    is => 'lazy',
    default => sub { FixMyStreet->config('TWILIO_MESSAGING_SERVICE_SID') },
);

sub send_token {
    my ($class, $token_data, $token_scope, $to) = @_;

    # Random number between 10,000 and 75,535
    my $random = 10000 + unpack('n', mySociety::Random::random_bytes(2, 1));
    $token_data->{code} = $random;
    my $token_obj = FixMyStreet::DB->resultset("Token")->create({
        scope => $token_scope,
        data => $token_data,
    });
    my $body = sprintf(_("Your verification code is %s"), $random);

    my $result = $class->new->send(to => $to, body => $body);
    return {
        random => $random,
        token => $token_obj->token,
        %$result,
    };
}

sub send {
    my ($self, %params) = @_;
    my $output = $self->twilio->POST('Messages.json', 
        $self->from ? (From => $self->from) : (),
        $self->messaging_service ? (MessagingServiceSid => $self->messaging_service) : (),
        To => $params{to},
        Body => $params{body},
    );
    my $data = decode_json($output->{content});
    if ($output->{code} >= 400) {
        return { error => "$data->{message} ($data->{code})" };
    }
    return { success => $data->{sid} };
}

=head2 parse_username

Given a string that might be an email address or a phone number,
return what we think it is, and if it's valid one of those. Or
undef if it's empty.

=cut

sub parse_username {
    my ($class, $username) = @_;

    return { type => 'email', username => $username } unless $username;

    $username = lc $username;
    $username =~ s/\s+//g;

    return { type => 'email', email => $username, username => $username } if is_valid_email($username);

    my $type = $username =~ /^[^a-z]+$/i ? 'phone' : 'email';
    my $phone = do {
        if ($username =~ /^\+/) {
            # If already in international format, use that
            Number::Phone::Lib->new($username)
        } else {
            # Otherwise, assume it is country configured
            my $country = FixMyStreet->config('PHONE_COUNTRY');
            Number::Phone::Lib->new($country, $username);
        }
    };

    my $may_be_mobile = 0;
    if ($phone) {
        $type = 'phone';
        # Store phone without spaces
        ($username = $phone->format) =~ s/\s+//g;
        # Is this mobile definitely or possibly a mobile? (+1 numbers)
        $may_be_mobile = 1 if $phone->is_mobile || (!defined $phone->is_mobile && $phone->is_geographic);
    }

    return {
        type => $type,
        phone => $phone,
        may_be_mobile => $may_be_mobile,
        username => $username,
    };
}

1;
