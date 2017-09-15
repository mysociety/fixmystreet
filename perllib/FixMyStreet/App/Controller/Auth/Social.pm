package FixMyStreet::App::Controller::Auth::Social;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Net::Facebook::Oauth2;
use Net::Twitter::Lite::WithAPIv1_1;

=head1 NAME

FixMyStreet::App::Controller::Auth::Social - Catalyst Controller

=head1 DESCRIPTION

Controller for the Facebook/Twitter authentication.

=head1 METHODS

=head2 facebook_sign_in

Starts the Facebook authentication sequence.

=cut

sub fb : Private {
    my ($self, $c) = @_;
    Net::Facebook::Oauth2->new(
        application_id => $c->config->{FACEBOOK_APP_ID},
        application_secret => $c->config->{FACEBOOK_APP_SECRET},
        callback => $c->uri_for('/auth/Facebook'),
    );
}

sub facebook_sign_in : Private {
    my ( $self, $c ) = @_;

    $c->detach( '/page_error_403_access_denied', [] ) if FixMyStreet->config('SIGNUPS_DISABLED');

    my $fb = $c->forward('fb');
    my $url = $fb->get_authorization_url(scope => ['email']);

    my %oauth;
    $oauth{return_url} = $c->get_param('r');
    $oauth{detach_to} = $c->stash->{detach_to};
    $oauth{detach_args} = $c->stash->{detach_args};
    $c->session->{oauth} = \%oauth;
    $c->res->redirect($url);
}

=head2 facebook_callback

Handles the Facebook callback request and completes the authentication sequence.

=cut

sub facebook_callback: Path('/auth/Facebook') : Args(0) {
    my ( $self, $c ) = @_;

    $c->detach('oauth_failure') if $c->get_param('error_code');

    my $fb = $c->forward('fb');
    my $access_token;
    eval {
        $access_token = $fb->get_access_token(code => $c->get_param('code'));
    };
    if ($@) {
        (my $message = $@) =~ s/at [^ ]*Auth.pm.*//;
        $c->detach('/page_error_500_internal_error', [ $message ]);
    }

    # save this token in session
    $c->session->{oauth}{token} = $access_token;

    my $info = $fb->get('https://graph.facebook.com/me?fields=name,email')->as_hash();
    my $email = lc ($info->{email} || "");
    $c->forward('oauth_success', [ 'facebook', $info->{id}, $info->{name}, $email ]);
}

=head2 twitter_sign_in

Starts the Twitter authentication sequence.

=cut

sub tw : Private {
    my ($self, $c) = @_;
    Net::Twitter::Lite::WithAPIv1_1->new(
        ssl => 1,
        consumer_key => $c->config->{TWITTER_KEY},
        consumer_secret => $c->config->{TWITTER_SECRET},
    );
}

sub twitter_sign_in : Private {
    my ( $self, $c ) = @_;

    $c->detach( '/page_error_403_access_denied', [] ) if FixMyStreet->config('SIGNUPS_DISABLED');

    my $twitter = $c->forward('tw');
    my $url = $twitter->get_authentication_url(callback => $c->uri_for('/auth/Twitter'));

    my %oauth;
    $oauth{return_url} = $c->get_param('r');
    $oauth{detach_to} = $c->stash->{detach_to};
    $oauth{detach_args} = $c->stash->{detach_args};
    $oauth{token} = $twitter->request_token;
    $oauth{token_secret} = $twitter->request_token_secret;
    $c->session->{oauth} = \%oauth;
    $c->res->redirect($url);
}

=head2 twitter_callback

Handles the Twitter callback request and completes the authentication sequence.

=cut

sub twitter_callback: Path('/auth/Twitter') : Args(0) {
    my ( $self, $c ) = @_;

    my $request_token = $c->req->param('oauth_token');
    my $verifier = $c->req->param('oauth_verifier');
    my $oauth = $c->session->{oauth};

    $c->detach('oauth_failure') if $c->get_param('denied') || $request_token ne $oauth->{token};

    my $twitter = $c->forward('tw');
    $twitter->request_token($oauth->{token});
    $twitter->request_token_secret($oauth->{token_secret});

    eval {
        # request_access_token no longer returns UID or name
        $twitter->request_access_token(verifier => $verifier);
    };
    if ($@) {
        (my $message = $@) =~ s/at [^ ]*Auth.pm.*//;
        $c->detach('/page_error_500_internal_error', [ $message ]);
    }

    my $info = $twitter->verify_credentials();
    $c->forward('oauth_success', [ 'twitter', $info->{id}, $info->{name} ]);
}

sub oauth_failure : Private {
    my ( $self, $c ) = @_;

    $c->stash->{oauth_failure} = 1;
    if ($c->session->{oauth}{detach_to}) {
        $c->detach($c->session->{oauth}{detach_to}, $c->session->{oauth}{detach_args});
    } else {
        $c->stash->{template} = 'auth/general.html';
        $c->detach;
    }
}

sub oauth_success : Private {
    my ($self, $c, $type, $uid, $name, $email) = @_;

    my $user;
    if ($email) {
        # Only Facebook gets here
        # We've got an ID and an email address
        # Remove any existing mention of this ID
        my $existing = $c->model('DB::User')->find( { facebook_id => $uid } );
        $existing->update( { facebook_id => undef } ) if $existing;
        # Get or create a user, give it this Facebook ID
        $user = $c->model('DB::User')->find_or_new( { email => $email } );
        $user->facebook_id($uid);
        $user->name($name);
        $user->in_storage() ? $user->update : $user->insert;
    } else {
        # We've got an ID, but no email
        $user = $c->model('DB::User')->find( { $type . '_id' => $uid } );
        if ($user) {
            # Matching ID in our database
            $user->name($name);
            $user->update;
        } else {
            # No matching ID, store ID for use later
            $c->session->{oauth}{$type . '_id'} = $uid;
            $c->stash->{oauth_need_email} = 1;
        }
    }

    # If we've got here with a full user, log in
    if ($user) {
        $c->authenticate( { email => $user->email, email_verified => 1 }, 'no_password' );
        $c->stash->{login_success} = 1;
    }

    if ($c->session->{oauth}{detach_to}) {
        $c->detach($c->session->{oauth}{detach_to}, $c->session->{oauth}{detach_args});
    } elsif ($c->stash->{oauth_need_email}) {
        $c->stash->{template} = 'auth/general.html';
    } else {
        $c->detach( '/auth/redirect_on_signin', [ $c->session->{oauth}{return_url} ] );
    }
}

__PACKAGE__->meta->make_immutable;

1;
