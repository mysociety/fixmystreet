package FixMyStreet::App::Controller::Auth::Social;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Net::Facebook::Oauth2;
use Net::Twitter::Lite::WithAPIv1_1;
use OIDC::Lite::Client::WebServer::Azure;
use URI::Escape;

use mySociety::AuthToken;

=head1 NAME

FixMyStreet::App::Controller::Auth::Social - Catalyst Controller

=head1 DESCRIPTION

Controller for the Facebook/Twitter/OpenID Connect authentication.

=head1 METHODS

=head2 handle_sign_in

Forwards to the appropriate (facebook|twitter|oidc)_sign_in method
based on the social_sign_in parameter

=cut

sub handle_sign_in : Private {
    my ($self, $c) = @_;

    $c->detach('facebook_sign_in') if $c->get_param('social_sign_in') eq 'facebook';
    $c->detach('twitter_sign_in') if $c->get_param('social_sign_in') eq 'twitter';
    $c->detach('oidc_sign_in') if $c->get_param('social_sign_in') eq 'oidc';

}

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

sub oidc : Private {
    my ($self, $c) = @_;

    my $config = $c->cobrand->feature('oidc_login');

    OIDC::Lite::Client::WebServer::Azure->new(
        id               => $config->{client_id},
        secret           => $config->{secret},
        authorize_uri    => $config->{auth_uri},
        access_token_uri => $config->{token_uri},
    );
}

sub oidc_sign_in : Private {
    my ( $self, $c ) = @_;

    $c->detach( '/page_error_403_access_denied', [] ) if FixMyStreet->config('SIGNUPS_DISABLED');
    $c->detach( '/page_error_400_bad_request', [] ) unless $c->cobrand->feature('oidc_login');

    my $oidc = $c->forward('oidc');
    my $nonce = $self->generate_nonce();
    my $url = $oidc->uri_to_redirect(
        redirect_uri => $c->uri_for('/auth/OIDC'),
        scope        => 'openid',
        state        => 'login',
        extra        => {
            response_mode => 'form_post',
            nonce         => $nonce,
        },
    );

    my %oauth;
    $oauth{return_url} = $c->get_param('r');
    $oauth{detach_to} = $c->stash->{detach_to};
    $oauth{detach_args} = $c->stash->{detach_args};
    $oauth{nonce} = $nonce;

    # The OIDC endpoint may require a specific URI to be called to log the user
    # out when they log out of FMS.
    if ( my $redirect_uri = $c->cobrand->feature('oidc_login')->{logout_uri} ) {
        $redirect_uri .= "?post_logout_redirect_uri=";
        $redirect_uri .= URI::Escape::uri_escape( $c->uri_for('/auth/sign_out') );
        $oauth{logout_redirect_uri} = $redirect_uri;
    }

    # The OIDC endpoint may provide a specific URI for changing the user's password.
    if ( my $password_change_uri = $c->cobrand->feature('oidc_login')->{password_change_uri} ) {
        $oauth{change_password_uri} = $oidc->uri_to_redirect(
            uri          => $password_change_uri,
            redirect_uri => $c->uri_for('/auth/OIDC'),
            scope        => 'openid',
            state        => 'password_change',
            extra        => {
                response_mode => 'form_post',
            },
        );
    }

    $c->session->{oauth} = \%oauth;
    $c->res->redirect($url);
}

sub oidc_callback: Path('/auth/OIDC') : Args(0) {
    my ( $self, $c ) = @_;

    my $oidc = $c->forward('oidc');

    if ($c->get_param('error')) {
        my $error_desc = $c->get_param('error_description');
        my $password_reset_uri = $c->cobrand->feature('oidc_login')->{password_reset_uri};
        if ($password_reset_uri && $error_desc =~ /^AADB2C90118:/) {
            my $url = $oidc->uri_to_redirect(
                uri          => $password_reset_uri,
                redirect_uri => $c->uri_for('/auth/OIDC'),
                scope        => 'openid',
                state        => 'password_reset',
                extra        => {
                    response_mode => 'form_post',
                },
            );
            $c->res->redirect($url);
            $c->detach;
        } elsif ($c->user_exists && $c->get_param('state') && $c->get_param('state') eq 'password_change') {
            $c->flash->{flash_message} = _('Password change cancelled.');
            $c->res->redirect('/my');
            $c->detach;
        } else {
            $c->detach('oauth_failure');
        }
    }
    $c->detach('/page_error_400_bad_request', []) unless $c->get_param('code') && $c->get_param('state');

    # After a password reset on the OIDC endpoint the user isn't properly logged
    # in, so redirect them to the usual OIDC login process.
    if ( $c->get_param('state') eq 'password_reset' ) {
        # The user may have reset their password as part of the sign-in-during-report
        # process, so preserve their report and redirect them to the right place
        # if that happened.
        if ( $c->session->{oauth} ) {
            $c->stash->{detach_to} = $c->session->{oauth}{detach_to};
            $c->stash->{detach_args} = $c->session->{oauth}{detach_args};
        }
        $c->detach('oidc_sign_in', []);
    }

    # User may be coming back here after changing their password on the OIDC endpoint
    if ($c->user_exists && $c->get_param('state') && $c->get_param('state') eq 'password_change') {
        $c->detach('/auth/profile/change_password_success', []);
    }

    # The only other valid state param is 'login' at this point.
    $c->detach('/page_error_400_bad_request', []) unless $c->get_param('state') eq 'login';

    my $id_token;
    eval {
        $id_token = $oidc->get_access_token(
            code => $c->get_param('code'),
        );
    };
    if ($@) {
        (my $message = $@) =~ s/at [^ ]*Auth.pm.*//;
        $c->detach('/page_error_500_internal_error', [ $message ]);
    }

    $c->detach('oauth_failure') unless $id_token;

    # sanity check the token audience is us...
    $c->detach('/page_error_500_internal_error', ['invalid id_token']) unless $id_token->payload->{aud} eq $c->cobrand->feature('oidc_login')->{client_id};

    # check that the nonce matches what we set in the user session
    $c->detach('/page_error_500_internal_error', ['invalid id_token']) unless $id_token->payload->{nonce} eq $c->session->{oauth}{nonce};

    # Some claims need parsing into a friendlier format
    # XXX check how much of this is Westminster/Azure-specific
    my $name = join(" ", $id_token->payload->{given_name}, $id_token->payload->{family_name});
    my $email = $id_token->payload->{email};
    # WCC Azure provides a single email address as an array for some reason
    my $emails = $id_token->payload->{emails};
    if ($emails && @$emails) {
        $email = $emails->[0];
    }

    # There's a chance that a user may have multiple OIDC logins, so build a namespaced uid to prevent collisions
    my $uid = join(":", $c->cobrand->moniker, $c->cobrand->feature('oidc_login')->{client_id}, $id_token->payload->{sub});

    # The cobrand may want to set values in the user extra field, e.g. a CRM ID
    # which is passed to Open311 with reports made by this user.
    my $extra = $c->cobrand->call_hook(oidc_user_extra => $id_token);

    $c->forward('oauth_success', [ 'oidc', $uid, $name, $email, $extra ]);
}

# Just a wrapper around random_token to make mocking easier.
sub generate_nonce : Private {
    my ($self, $c) = @_;

    return mySociety::AuthToken::random_token();
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
    my ($self, $c, $type, $uid, $name, $email, $extra) = @_;

    my $user;
    if ($email) {
        # Only Facebook & OIDC get here
        # We've got an ID and an email address

        # Remove any existing mention of this ID
        my $existing;
        if ($type eq 'facebook') {
            $existing = $c->model('DB::User')->find( { $type . '_id' => $uid } );
            $existing->update( { $type . '_id' => undef } ) if $existing;
        } elsif ( $type eq 'oidc' ) {
            $existing = $c->model('DB::User')->find( { oidc_ids => \[
                '&& ?', [ oidc_ids => [ $uid ] ]
            ] } );
            $existing->remove_oidc_id( $uid ) if $existing;
        }

        # Get or create a user, give it this Facebook/OIDC ID
        $user = $c->model('DB::User')->find_or_new( { email => $email } );
        if ( $type eq 'facebook' ) {
            $user->facebook_id($uid);
        } elsif ( $type eq 'oidc' ) {
            $user->add_oidc_id($uid);
        }
        $user->name($name);
        if ($extra) {
            $user->extra({
                %{ $user->get_extra() },
                %$extra
            });
        }
        $user->in_storage() ? $user->update : $user->insert;
    } else {
        # We've got an ID, but no email
        if ($type eq 'oidc') {
           $user = $c->model('DB::User')->find( { oidc_ids => \[
                '&& ?', [ oidc_ids => [ $uid ] ]
            ] } );
        } else {
            $user = $c->model('DB::User')->find( { $type . '_id' => $uid } );
        }
        if ($user) {
            # Matching ID in our database
            $user->name($name);
            if ($extra) {
                $user->extra({
                    %{ $user->get_extra() },
                    %$extra
                });
            }
            $user->update;
        } else {
            # No matching ID, store ID for use later
            $c->session->{oauth}{$type . '_id'} = $uid;
            $c->session->{oauth}{name} = $name;
            $c->session->{oauth}{extra} = $extra;
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
