package Catalyst::Authentication::Credential::2FA;

use strict;
use warnings;
use FixMyStreet::Auth::GoogleAuth;

our $VERSION = "0.01";

sub new {
    my ($class, $config, $c, $realm) = @_;
    my $self = { %$config };
    bless $self, $class;
    return $self;
}

sub authenticate {
    my ( $self, $c, $realm, $authinfo ) = @_;

    my $userfindauthinfo = {%{$authinfo}};
    delete($userfindauthinfo->{password});

    my $user_obj = $realm->find_user($userfindauthinfo, $c);
    if (ref($user_obj)) {

        # We don't care unless user has a 2FA secret, or the cobrand mandates it
        # We also don't care if the cobrand says we don't
        my $must_have_2fa = $c->cobrand->call_hook('must_have_2fa', $user_obj) || '';
        return $user_obj if $must_have_2fa eq 'skip' || !($user_obj->has_2fa || $must_have_2fa);

        $c->stash->{token} = $c->get_param('token');

        if (!$user_obj->has_2fa) {
            $c->stash->{template} = 'auth/2fa/intro.html';
            my $action = $c->get_param('2fa_action') || '';

            my $secret;
            if ($action eq 'confirm') {
                $secret = $c->get_param('secret32');
                if ($c->check_2fa($secret)) {
                    $user_obj->set_extra_metadata('2fa_secret' => $secret);
                    $user_obj->update;
                    if ($c->stash->{token}) {
                        my $token = $c->forward('/tokens/load_auth_token', [ $c->stash->{token}, '2fa' ]);
                        # Will contain a detach_to and report/update data
                        $c->stash($token->data);
                    } else {
                        $c->stash->{stage} = 'success';
                        $c->stash->{detach_to} = '/auth/two_factor_setup_success';
                    }
                    return $user_obj;
                } else {
                    $action = 'activate'; # Incorrect code, reshow
                }
            }

            if ($action eq 'activate') {
                my $auth = FixMyStreet::Auth::GoogleAuth->new;
                $c->stash->{qr_code} = $auth->qr_code($secret, $user_obj->email, $c->cobrand->base_url);
                $c->stash->{secret32} = $auth->secret32;
                $c->stash->{stage} = 'activate';
            }

            if ($c->stash->{tfa_data}) {
                my $token = $c->model("DB::Token")->create( {
                    scope => '2fa',
                    data => $c->stash->{tfa_data},
                });
                $c->stash->{token} = $token->token;
            }

            $c->detach;
        }

        if ($c->check_2fa($user_obj->has_2fa)) {
            if ($c->stash->{token}) {
                my $token = $c->forward('/tokens/load_auth_token', [ $c->stash->{token}, '2fa' ]);
                # Will contain a detach_to and report/update data
                $c->stash($token->data);
            }
            return $user_obj;
        }

        if ($c->stash->{tfa_data}) {
            my $token = $c->model("DB::Token")->create( {
                scope => '2fa',
                data => $c->stash->{tfa_data},
            });
            $c->stash->{token} = $token->token;
        }

        $c->stash->{template} = 'auth/2fa/form.html';
        $c->detach;
    }
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Catalyst::Authentication::Credential::2FA - Authenticate a user
with a two-factor authentication code.

=head1 SYNOPSIS

    use Catalyst qw/
      Authentication
      /;

    package MyApp::Controller::Auth;

    sub login : Local {
        my ( $self, $c ) = @_;

        $c->authenticate( { username => $c->req->param('username'),
                            password => $c->req->param('password') });
    }

=head1 DESCRIPTION

This authentication credential checker takes authentication information
(most often a username), and only passes if a valid 2FA code is then
entered. It only works for Users that have a 2FA secret stored in a
FixMyStreet::Role::Extra metadata key.

=head1 CONFIGURATION

    # example
    'Plugin::Authentication' => {
        default => {
            credential => {
                class => 'MultiFactor',
                factors => [
                  {
                      class => 'Password',
                      password_field => 'password',
                      password_type => 'self_check',
                  },
                  {
                      class => '2FA',
                  },
                ],
            },
            store => {
                class  => 'DBIx::Class',
                user_model => 'DB::User',
            },
        },


=over 4

=item class

The classname used for Credential. This is part of
L<Catalyst::Plugin::Authentication> and is the method by which
Catalyst::Authentication::Credential::2FA is loaded as the
credential validator. For this module to be used, this must be set to
'2FA'.

=back

=head1 USAGE

Once configured as indicated above, authenticating using this module is a
matter of calling $c->authenticate() as normal. If you wish to use it in
combination with e.g. password authentication as well (so it actually is
two-factor!), check out Catalyst::Authentication::Credential::MultiFactor.

=cut
