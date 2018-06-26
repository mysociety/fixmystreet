package FixMyStreet::App::Controller::Auth;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Email::Valid;
use Data::Password::Common 'found';
use Digest::HMAC_SHA1 qw(hmac_sha1);
use JSON::MaybeXS;
use MIME::Base64;
use FixMyStreet::SMS;

=head1 NAME

FixMyStreet::App::Controller::Auth - Catalyst Controller

=head1 DESCRIPTION

Controller for all the authentication related pages - create account, sign in,
sign out.

=head1 METHODS

=head2 index

Present the user with a sign in / create account page.

=cut

sub general : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->detach( 'redirect_on_signin', [ $c->get_param('r') ] )
        if $c->req->method eq 'GET' && $c->user && $c->get_param('r');

    # all done unless we have a form posted to us
    return unless $c->req->method eq 'POST';

    my $clicked_sign_in_by_code = $c->get_param('sign_in_by_code');
    my $data_username = $c->get_param('username');
    my $data_password = $c->get_param('password_sign_in');
    my $data_email = $c->get_param('name') || $c->get_param('password_register');

    # decide which action to take
    $c->detach('code_sign_in') if $clicked_sign_in_by_code || ($data_email && !$data_password);
    if (!$data_username && !$data_password && !$data_email) {
        $c->detach('social/facebook_sign_in') if $c->get_param('facebook_sign_in');
        $c->detach('social/twitter_sign_in') if $c->get_param('twitter_sign_in');
    }

       $c->forward( 'sign_in', [ $data_username ] )
    && $c->detach( 'redirect_on_signin', [ $c->get_param('r') ] );

}

sub general_test : Path('_test_') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'auth/token.html';
}

sub authenticate : Private {
    my ($self, $c, $type, $username, $password) = @_;
    return 1 if $type eq 'email' && $c->authenticate({ email => $username, email_verified => 1, password => $password });
    return 1 if FixMyStreet->config('SMS_AUTHENTICATION') && $type eq 'phone' && $c->authenticate({ phone => $username, phone_verified => 1, password => $password });
    return 0;
}

=head2 sign_in

Allow the user to sign in with a username and a password.

=cut

sub sign_in : Private {
    my ( $self, $c, $username ) = @_;

    $username ||= '';
    my $password = $c->get_param('password_sign_in') || '';
    my $remember_me = $c->get_param('remember_me') || 0;

    # Sign out just in case
    $c->logout();

    my $parsed = FixMyStreet::SMS->parse_username($username);

    if ($parsed->{username} && $password && $c->forward('authenticate', [ $parsed->{type}, $parsed->{username}, $password ])) {
        # Upgrade hash count if necessary
        my $cost = sprintf("%02d", FixMyStreet::DB::Result::User->cost);
        if ($c->user->password !~ /^\$2a\$$cost\$/) {
            $c->user->update({ password => $password });
        }

        # unless user asked to be remembered limit the session to browser
        $c->set_session_cookie_expire(0)
          unless $remember_me;

        # Regenerate CSRF token as session ID changed
        $c->forward('get_csrf_token');

        return 1;
    }

    $c->stash(
        sign_in_error => 1,
        username => $username,
        remember_me => $remember_me,
    );
    return;
}

=head2 code_sign_in

Either email the user a link to sign in, or send an SMS token to do so.

Don't check for an account - if there isn't one we can create it when
they come back with a token (which contains the email/phone).

=cut

sub code_sign_in : Private {
    my ( $self, $c ) = @_;

    my $username = $c->stash->{username} = $c->get_param('username') || '';

    my $parsed = FixMyStreet::SMS->parse_username($username);

    if ($parsed->{type} eq 'phone' && FixMyStreet->config('SMS_AUTHENTICATION')) {
        $c->forward('phone/sign_in', [ $parsed ]);
    } else {
        $c->forward('email_sign_in', [ $parsed->{username} ]);
    }
}

sub email_sign_in : Private {
    my ( $self, $c, $email ) = @_;

    # check that the email is valid - otherwise flag an error
    my $raw_email = lc( $email || '' );

    my $email_checker = Email::Valid->new(
        -mxcheck  => 1,
        -tldcheck => 1,
        -fqdn     => 1,
    );

    my $good_email = $email_checker->address($raw_email);
    if ( !$good_email ) {
        $c->stash->{username_error} = $raw_email ? $email_checker->details : 'missing_email';
        return;
    }

    my $password = $c->get_param('password_register');
    if ($password) {
        return unless $c->forward('/auth/test_password', [ $password ]);
    }

    # If user registration is disabled then bail out at this point
    # if there's not already a user with this email address.
    # NB this uses the same template as a successful sign in to stop
    # enumeration of valid email addresses.
    if ( FixMyStreet->config('SIGNUPS_DISABLED')
         && !$c->model('DB::User')->find({ email => $good_email })
         && !$c->stash->{current_user} # don't break the change email flow
    ) {
        $c->stash->{template} = 'auth/token.html';
        return;
    }

    my $user_params = {};
    $user_params->{password} = $password if $password;
    my $user = $c->model('DB::User')->new( $user_params );

    my $token_data = {
        email => $good_email,
        r => $c->get_param('r'),
        name => $c->get_param('name'),
        password => $user->password,
    };
    $token_data->{facebook_id} = $c->session->{oauth}{facebook_id}
        if $c->get_param('oauth_need_email') && $c->session->{oauth}{facebook_id};
    $token_data->{twitter_id} = $c->session->{oauth}{twitter_id}
        if $c->get_param('oauth_need_email') && $c->session->{oauth}{twitter_id};
    if ($c->stash->{current_user}) {
        $token_data->{old_user_id} = $c->stash->{current_user}->id;
        $token_data->{r} = 'auth/change_email/success';
    }

    my $token_obj = $c->model('DB::Token')->create({
        scope => 'email_sign_in',
        data  => $token_data,
    });

    $c->stash->{token} = $token_obj->token;
    my $template = $c->stash->{email_template} || 'login.txt';
    $c->send_email( $template, { to => $good_email } );
    $c->stash->{template} = 'auth/token.html';
}

sub get_token : Private {
    my ( $self, $c, $token, $scope ) = @_;

    $c->stash->{token_not_found} = 1, return unless $token;

    my $token_obj = $c->model('DB::Token')->find({ scope => $scope, token => $token });

    $c->stash->{token_not_found} = 1, return unless $token_obj;
    $c->stash->{token_not_found} = 1, return if $token_obj->created < DateTime->now->subtract( days => 1 );

    my $data = $token_obj->data;
    return $data;
}

=head2 token

Handle the 'email_sign_in' tokens. Find the account for the email address
(creating if needed), authenticate the user and delete the token.

=cut

sub token : Path('/M') : Args(1) {
    my ( $self, $c, $url_token ) = @_;

    my $data = $c->forward('get_token', [ $url_token, 'email_sign_in' ]) || return;

    $c->stash->{token_not_found} = 1, return
        if $data->{old_user_id} && (!$c->user_exists || $c->user->id ne $data->{old_user_id});

    my $type = $data->{login_type} || 'email';
    $c->detach( '/auth/process_login', [ $data, $type ] );
}

sub process_login : Private {
    my ( $self, $c, $data, $type ) = @_;

    # sign out in case we are another user
    $c->logout();

    my $user = $c->model('DB::User')->find_or_new({ $type => $data->{$type} });
    my $ver = "${type}_verified";

    # Bail out if this is a new user and SIGNUPS_DISABLED is set
    $c->detach( '/page_error_403_access_denied', [] )
        if FixMyStreet->config('SIGNUPS_DISABLED') && !$user->in_storage && !$data->{old_user_id};

    # Superusers using 2FA can not log in by code
    $c->detach( '/page_error_403_access_denied', [] ) if $user->has_2fa;

    if ($data->{old_user_id}) {
        # Were logged in as old_user_id, want to switch to $user
        if ($user->in_storage) {
            my $old_user = $c->model('DB::User')->find({ id => $data->{old_user_id} });
            if ($old_user) {
                $old_user->adopt($user);
                $user = $old_user;
                $user->$type($data->{$type});
                $user->$ver(1);
            }
        } else {
            # Updating to a new (to the db) email address/phone number, easier!
            $user = $c->model('DB::User')->find({ id => $data->{old_user_id} });
            $user->$type($data->{$type});
            $user->$ver(1);
        }
    }

    $user->name( $data->{name} ) if $data->{name};
    $user->password( $data->{password}, 1 ) if $data->{password};
    $user->facebook_id( $data->{facebook_id} ) if $data->{facebook_id};
    $user->twitter_id( $data->{twitter_id} ) if $data->{twitter_id};
    $user->update_or_insert;
    $c->authenticate( { $type => $data->{$type}, $ver => 1 }, 'no_password' );

    # send the user to their page
    $c->detach( 'redirect_on_signin', [ $data->{r}, $data->{p} ] );
}

=head2 redirect_on_signin

Used after signing in to take the person back to where they were.

=cut


sub redirect_on_signin : Private {
    my ( $self, $c, $redirect, $params ) = @_;

    if ($c->stash->{detach_to}) {
        $c->detach($c->stash->{detach_to}, $c->stash->{detach_args});
    }

    unless ( $redirect ) {
        $c->detach('redirect_to_categories') if $c->user->from_body && scalar @{ $c->user->categories };
        $redirect = 'my';
    }
    $redirect = 'my' if $redirect =~ /^admin/ && !$c->cobrand->admin_allow_user($c->user);
    if ( $c->cobrand->moniker eq 'zurich' ) {
        $redirect = 'admin' if $c->user->from_body;
    }
    if (defined $params) {
        $c->res->redirect( $c->uri_for( "/$redirect", $params ) );
    } else {
        $c->res->redirect( $c->uri_for( "/$redirect" ) );
    }
}

=head2 redirect_to_categories

Redirects the user to their body's reports page, prefiltered to whatever
categories this user has been assigned to.

=cut

sub redirect_to_categories : Private {
    my ( $self, $c ) = @_;

    my $categories = $c->user->categories_string;
    my $body_short = $c->cobrand->short_name( $c->user->from_body );

    $c->res->redirect( $c->uri_for( "/reports/" . $body_short, { filter_category => $categories } ) );
}

=head2 redirect

Used when trying to view a page that requires sign in when you're not.

=cut

sub redirect : Private {
    my ( $self, $c ) = @_;

    my $uri = $c->uri_for( '/auth', { r => $c->req->path } );
    $c->res->redirect( $uri );
    $c->detach;

}

sub get_csrf_token : Private {
    my ( $self, $c ) = @_;

    my $time = $c->stash->{csrf_time} || time();
    my $hash = hmac_sha1("$time-" . ($c->sessionid || ""), $c->model('DB::Secret')->get);
    $hash = encode_base64($hash, "");
    $hash =~ s/=$//;
    my $token = "$time-$hash";
    $c->stash->{csrf_token} = $token unless $c->stash->{csrf_time};
    return $token;
}

sub check_csrf_token : Private {
    my ( $self, $c ) = @_;

    my $token = $c->get_param('token') || "";
    $token =~ s/ /+/g;
    my ($time) = $token =~ /^(\d+)-[0-9a-zA-Z+\/]+$/;
    $c->stash->{csrf_time} = $time;
    my $gen_token = $c->forward('get_csrf_token');
    delete $c->stash->{csrf_time};
    $c->detach('no_csrf_token')
        unless $time
            && $time > time() - 3600
            && $token eq $gen_token;
}

sub no_csrf_token : Private {
    my ($self, $c) = @_;
    $c->detach('/page_error_400_bad_request', []);
}

=item common_password

Returns 1/0 depending on if password is common or not.

=cut

sub common_password : Local : Args(0) {
    my ($self, $c) = @_;

    my $password = $c->get_param('password_register');

    my $return = JSON->true;
    if (!$c->cobrand->call_hook('bypass_password_checks') && found($password)) {
        $return = _('Please choose a less commonly-used password');
    }

    my $body = JSON->new->utf8->allow_nonref->encode($return);
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($body);
}

=item test_password

Checks a password is not too weak; returns true if okay,
false if weak (and sets stash error).

=cut

sub test_password : Private {
    my ($self, $c, $password) = @_;

    return 1 if $c->cobrand->call_hook('bypass_password_checks');

    my @errors;

    my $min_length = $c->cobrand->password_minimum_length;
    push @errors, sprintf(_('Please make sure your password is at least %d characters long'), $min_length)
        if length($password) < $min_length;

    push @errors, _('Please choose a less commonly-used password')
        if found($password);

    if (@errors) {
        $c->stash->{field_errors}->{password_register} = join('<br>', @errors);
        return 0;
    }
    return 1;
}

=head2 sign_out

Log the user out. Tell them we've done so.

=cut

sub sign_out : Local {
    my ( $self, $c ) = @_;
    $c->logout();
}

sub ajax_sign_in : Path('ajax/sign_in') {
    my ( $self, $c ) = @_;

    my $return = {};
    if ( $c->forward( 'sign_in', [ $c->get_param('email') ] ) ) {
        $return->{name} = $c->user->name;
    } else {
        $return->{error} = 1;
    }

    my $body = encode_json($return);
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($body);

    return 1;
}

sub ajax_sign_out : Path('ajax/sign_out') {
    my ( $self, $c ) = @_;

    $c->logout();

    my $body = encode_json( { signed_out => 1 } );
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body($body);

    return 1;
}

sub ajax_check_auth : Path('ajax/check_auth') {
    my ( $self, $c ) = @_;

    my $code = 401;
    my $data = { not_authorized => 1 };

    if ( $c->user ) {
        $data = { name => $c->user->name };
        $code = 200;
    }

    my $body = encode_json($data);
    $c->res->content_type('application/json; charset=utf-8');
    $c->res->code($code);
    $c->res->body($body);

    return 1;
}

=head2 check_auth

Utility page - returns a simple message 'OK' and a 200 response if the user is
authenticated and a 'Unauthorized' / 401 reponse if they are not.

Mainly intended for testing but might also be useful for ajax calls.

=cut

sub check_auth : Local {
    my ( $self, $c ) = @_;

    $c->authenticate(undef, 'access_token') unless $c->user;

    # choose the response
    my ( $body, $code )    #
      = $c->user
      ? ( 'OK', 200 )
      : ( 'Unauthorized', 401 );

    # set the response
    $c->res->body($body);
    $c->res->code($code);

    # NOTE - really a 401 response should also contain a 'WWW-Authenticate'
    # header but we ignore that here. The spec is not keeping up with usage.

    return;
}

__PACKAGE__->meta->make_immutable;

1;
