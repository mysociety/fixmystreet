package FixMyStreet::App::Controller::Root;
use Digest::MD5 qw(md5_hex);
use mySociety::Random qw(random_bytes);
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config( namespace => '' );

=head1 NAME

FixMyStreet::App::Controller::Root - Root Controller for FixMyStreet::App

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 begin

Any pre-flight checking for all requests

=cut
sub begin : Private {
    my ( $self, $c ) = @_;

    $c->forward( 'check_login_required' );
}


=head2 auto

Set up general things for this instance

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    # decide which cobrand this request should use
    $c->setup_request();
    $c->forward('check_password_expiry');
    $c->detach('/auth/redirect') if $c->cobrand->call_hook('check_login_disallowed');

    $c->forward('/offline/_stash_manifest_theme', [ $c->cobrand->moniker ]);
    $c->forward('store_app_platform');

    return 1;
}

=head2 index

Home page.

If request includes certain parameters redirect to '/around' - this is to
preserve old behaviour.

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my @old_param_keys = ( 'pc', 'x', 'y', 'e', 'n', 'lat', 'lon' );
    my %old_params = ();

    foreach my $key (@old_param_keys) {
        my $val = $c->get_param($key);
        next unless $val;
        $old_params{$key} = $val;
    }

    if ( scalar keys %old_params ) {
        my $around_uri = $c->uri_for( '/around', \%old_params );
        $c->res->redirect($around_uri);
        return;
    }

    if ($c->stash->{homepage_template}) {
        $c->stash->{template} = $c->stash->{homepage_template};
        $c->detach;
    }

    $c->forward('/auth/get_csrf_token');
}

=head2 default

Forward to the standard 404 error page

=cut

sub default : Path {
    my ( $self, $c ) = @_;
    $c->detach('/page_error_404_not_found', []);
}

=head2 page_error_404_not_found, page_error_410_gone

    $c->detach( '/page_error_404_not_found', [$error_msg] );
    $c->detach( '/page_error_410_gone',      [$error_msg] );

Display a 404 (not found) or 410 (gone) page. Pass in an optional error message in an arrayref.

=cut

sub page_error_404_not_found : Private {
    my ( $self, $c, $error_msg ) = @_;

    # Try getting static content that might be given under an admin proxy.
    # First the special generated JavaScript file
    $c->go('/js/translation_strings', [ $1 ], []) if $c->req->path =~ m{^admin/js/translation_strings\.(.*?)\.js$};
    # Then a generic static file
    $c->serve_static_file("web/$1") && return if $c->req->path =~ m{^admin/(.*)};

    $c->stash->{template}  = 'errors/page_error_404_not_found.html';
    $c->stash->{error_msg} = $error_msg;
    $c->response->status(404);
}

sub page_error_410_gone : Private {
    my ( $self, $c, $error_msg ) = @_;
    $c->stash->{template}  = 'index.html';
    $c->stash->{gone_error} = $error_msg;
    $c->response->status(410);
}

sub page_error_403_access_denied : Private {
    my ( $self, $c, $error_msg ) = @_;
    $c->stash->{title} = _('Access denied');
    $error_msg ||= _("Sorry, you don't have permission to do that.");
    $c->detach('page_error', [ $error_msg, 403 ]);
}

sub page_error_400_bad_request : Private {
    my ( $self, $c, $error_msg ) = @_;
    $c->forward('/auth/get_csrf_token');
    $c->detach('page_error', [ $error_msg, 400 ]);
}

sub page_error_500_internal_error : Private {
    my ( $self, $c, $error_msg ) = @_;
    $c->response->header('X-Custom-Error-Provided' => 'yes');
    $c->detach('page_error', [ $error_msg, 500 ]);
}

sub page_error : Private {
    my ($self, $c, $error_msg, $code) = @_;
    $c->stash->{template} = 'errors/generic.html';
    $c->stash->{message}  = $error_msg || _('Unknown error');
    $c->stash->{error_id} = substr(md5_hex(random_bytes(12, 1)), 0, 6);

    my $addr = $c->req->address;
    $c->log->info(
        "page_error (HTTP $code, IP $addr, ID " .
        $c->stash->{error_id} . "): " .
        "User message: " . $c->stash->{message} .
        ($c->stash->{internal_message} ? "; Internal message: " . $c->stash->{internal_message} : "")
    );
    $c->response->status($code);
}

sub check_login_required : Private {
    my ($self, $c) = @_;

    return if $c->user_exists || !FixMyStreet->config('LOGIN_REQUIRED');

    # Whitelisted URL patterns are allowed without login
    my $whitelist = qr{
          ^auth(/|$)
        | ^js/translation_strings\.(.*?)\.js
        | ^[PACQM]/  # various tokens that log the user in
    }x;
    return if $c->request->path =~ $whitelist;

    $c->detach( '/auth/redirect' );
}

sub check_password_expiry : Private {
    my ($self, $c) = @_;

    return unless $c->user_exists;

    return if $c->action eq $c->controller('JS')->action_for('translation_strings');
    return if $c->controller eq $c->controller('Auth');

    my $expiry = $c->cobrand->call_hook('password_expiry');
    return unless $expiry;

    my $last_change = $c->user->get_extra_metadata('last_password_change') || 0;
    my $midnight = int(time()/86400)*86400;
    my $expired = $last_change + $expiry < $midnight;
    return unless $expired;

    my $uri = $c->uri_for('/auth/expired');
    $c->res->redirect( $uri );
    $c->detach;
}

sub set_app_cors_header : Private {
    my ($self, $c) = @_;
    my $origin = $c->req->header('Origin') || '';
    $c->response->header('Access-Control-Allow-Origin' => 'app://localhost') if $origin eq 'app://localhost';
}


=head2 store_app_platform

If the user is accessing the site via the wrapped PWA from the app store, we want
to record this fact with the reports they make as it can be helpful for debugging
or analysis later on.

This method attempts to determine if the user is on the iOS or Android device
by looking at the C<pwa> query parameter used for the request (if present) and
the User-Agent and Referer headers.

iOS users will start at /?pwa=ios and all requests will have 'iospwa' at the end
of their User-Agent header.

Android users will start at /?pwa=android and the first request they make will
have a Referer header of android-app://org.mysociety.fixmystreet/ (NB the actual
package ID is pulled from COBRAND_FEATURES so as to make this feature reusable
across installations.)

This method is called for every URL, rather than just /, because we can't
assume the user will always start at / - they may follow a link in an alert
email to a particular report, or a report confirmation email etc.

=cut

sub store_app_platform : Private {
    my ($self, $c) = @_;

    my $referer = $c->req->referer || "";
    my $ua = $c->req->user_agent || "";
    my $pwa = (grep { $_ eq 'pwa' } keys %{ $c->req->params }) ? 1 : 0;
    my $param = $c->get_param("pwa") || "";
    my $cfg = $c->cobrand->feature("android_assetlinks") || {};
    my $package = $cfg->{package} || "";

    if ( $param =~ /ios/i || $ua =~ /iospwa/i ) {
        $c->session->{app_platform} = "iOS";
    } elsif ( $param =~ /android/i || $referer =~ m{android-app://$package/}i ) {
        $c->session->{app_platform} = "Android";
    } elsif ( $pwa && !$param ) {
        $c->session->{app_platform} = "PWA";
    }
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
}

__PACKAGE__->meta->make_immutable;

1;
