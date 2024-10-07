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
use GovUkNotify;

has cobrand => ( is => 'ro' );

has twilio => (
    is => 'lazy',
    default => sub {
        my $sid = FixMyStreet->config('TWILIO_ACCOUNT_SID');
        return unless $sid;
        my $api = WWW::Twilio::API->new(
            AccountSid => $sid,
            AuthToken => FixMyStreet->config('TWILIO_AUTH_TOKEN'),
            utf8 => 1,
        );
        return {
            api => $api,
            from => FixMyStreet->config('TWILIO_FROM_PARAMETER'),
            messaging_service => FixMyStreet->config('TWILIO_MESSAGING_SERVICE_SID'),
        }
    },
);

has notify_choice => (
    is => 'ro',
    default => '',
);

has notify => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $cfg = $self->cobrand->feature('govuk_notify');
        my @cfg;
        my $key;
        if (ref $cfg eq 'ARRAY') {
            if ($self->notify_choice) {
                @cfg = grep { $_->{type} eq $self->notify_choice} @$cfg;
            } else {
                @cfg = grep { $_->{type} eq 'default' } @$cfg;
            }
            $cfg = $cfg[0];
            $key = $cfg->{key};
            return unless $key;
        } else {
            $key = $cfg->{key};
            return unless $key;
        }
        my $api = GovUkNotify->new(
            key => $key,
            template_id => $cfg->{template_id},
            sms_sender => $cfg->{sms_sender},
        );
        return $api;
    },
);

sub send_token {
    my ($class, $token_data, $token_scope, $to, $cobrand) = @_;

    # Random number between 10,000 and 75,535
    my $random = 10000 + unpack('n', mySociety::Random::random_bytes(2, 1));
    $token_data->{code} = $random;
    my $token_obj = FixMyStreet::DB->resultset("Token")->create({
        scope => $token_scope,
        data => $token_data,
    });
    my $body = sprintf(_("Your verification code is %s"), $random);

    my $result = $class->new(cobrand => $cobrand)->send(to => $to, body => $body);
    return {
        random => $random,
        token => $token_obj->token,
        %$result,
    };
}

sub send {
    my ($self, %params) = @_;

    my $twilio = $self->twilio;
    my $notify = $self->notify;
    unless ($twilio || $notify) {
        return { error => "No SMS service configured" };
    }

    if ($notify) {
        my $output = $notify->send(
            to => $params{to},
            body => $params{body},
        );
        my $data = decode_json($output->{content});
        if ($output->{code} >= 400) {
            return { error => "$data->{errors}[0]{message} ($data->{errors}[0]{error})" };
        }
        return { success => $data->{id} };
    }

    if ($twilio) {
        my $output = $twilio->{api}->POST('Messages.json',
            $twilio->{from} ? (From => $twilio->{from}) : (),
            $twilio->{messaging_service} ? (MessagingServiceSid => $twilio->{messaging_service}) : (),
            To => $params{to},
            Body => $params{body},
        );
        my $data = decode_json($output->{content});
        if ($output->{code} >= 400) {
            return { error => "$data->{message} ($data->{code})" };
        }
        return { success => $data->{sid} };
    }
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

    if (my $phone = test_number($username)) {
        return {
            type => 'phone',
            phone => $phone,
            may_be_mobile => 1,
            username => $username,
        };
    }

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

sub test_number {
    my $username = shift;
    my @notify_test_numbers = ('+447700900003', '+447700900002', '07700900003', '07700900002');
    foreach (@notify_test_numbers) {
        return FixMyStreet::SMS::TestNumber->new( number => $username ) if $username eq $_;
    }
    return 0;
}

package FixMyStreet::SMS::TestNumber;
use Moo;
has number => ( is => 'ro' );
sub format { $_[0]->number }
sub format_for_country { $_[0]->number }

1;
