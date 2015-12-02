package FixMyStreet::App;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;
use FixMyStreet;
use FixMyStreet::Cobrand;
use Memcached;
use mySociety::Email;
use mySociety::Random qw(random_bytes);
use FixMyStreet::Map;
use FixMyStreet::Email;
use Utils;

use Path::Class;
use URI;
use URI::QueryParam;

use Catalyst (
    'Static::Simple',    #
    'Unicode::Encoding',
    'Session',
    'Session::Store::DBIC',
    'Session::State::Cookie',    # FIXME - we're using our own override atm
    'Authentication',
    'SmartURI',
    'Compress::Gzip',
);

extends 'Catalyst';

our $VERSION = '0.01';

__PACKAGE__->config(

    # get the config from the core object
    %{ FixMyStreet->config() },

    name => 'FixMyStreet::App',

    encoding => 'UTF-8',

    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,

    # Some generic stuff
    default_view => 'Web',

    # Serve anything in web dir that is not a .cgi script
    'Plugin::Static::Simple' => {
        include_path      => [ FixMyStreet->path_to("web") . "" ],
        ignore_extensions => ['cgi'],
    },

    'Plugin::Session' => {    # Catalyst::Plugin::Session::Store::DBIC
        dbic_class     => 'DB::Session',
        expires        => 3600 * 24 * 7 * 4, # 4 weeks
        cookie_secure  => 2,
    },

    'Plugin::Authentication' => {
        default_realm => 'default',
        default       => {
            credential => {    # Catalyst::Authentication::Credential::Password
                class              => 'Password',
                password_field     => 'password',
                password_type      => 'self_check',
            },
            store => {         # Catalyst::Authentication::Store::DBIx::Class
                class      => 'DBIx::Class',
                user_model => 'DB::User',
            },
        },
        no_password => {       # use post confirm etc
            credential => {    # Catalyst::Authentication::Credential::Password
                class         => 'Password',
                password_type => 'none',
            },
            store => {         # Catalyst::Authentication::Store::DBIx::Class
                class      => 'DBIx::Class',
                user_model => 'DB::User',
            },
        },
    },
);

# Start the application
__PACKAGE__->setup();

# If your site is secure but running behind a proxy, you might need to set the
# SECURE_PROXY_SSL_HEADER configuration variable so this can be spotted.
after 'prepare_headers' => sub {
    my $self = shift;
    my $base_url = $self->config->{BASE_URL};
    my $ssl_header = $self->config->{SECURE_PROXY_SSL_HEADER};
    my $host = $self->req->headers->header('Host');
    $self->req->secure(1) if $ssl_header && ref $ssl_header eq 'ARRAY'
        && @$ssl_header == 2 && $self->req->header($ssl_header->[0]) eq $ssl_header->[1];
};

# set up DB handle for old code
FixMyStreet->configure_mysociety_dbhandle;

# disable debug logging unless in debug mode
__PACKAGE__->log->disable('debug')    #
  unless __PACKAGE__->debug;

=head1 NAME

FixMyStreet::App - Catalyst based application

=head1 SYNOPSIS

    script/fixmystreet_app_server.pl

=head1 DESCRIPTION

FixMyStreet.com codebase

=head1 METHODS

=head2 cobrand

    $cobrand = $c->cobrand();

Returns the cobrand object. If not already determined this request finds it and
caches it to the stash.

=cut

sub cobrand {
    my $c = shift;
    return $c->stash->{cobrand} ||= $c->_get_cobrand();
}

sub _get_cobrand {
    my $c = shift;

    my $host             = $c->req->uri->host;
    my $override_moniker = $c->get_override('cobrand_moniker');

    my $cobrand_class =
      $override_moniker
      ? FixMyStreet::Cobrand->get_class_for_moniker($override_moniker)
      : FixMyStreet::Cobrand->get_class_for_host($host);

    my $cobrand = $cobrand_class->new( { c => $c } );

    return $cobrand;
}

=head2 setup_request

    $cobrand = $c->setup_request();

Work out which cobrand we should be using. Set the environment correctly - eg
template paths, maps, languages etc, etc.

=cut

sub setup_request {
    my $c = shift;

    $c->setup_dev_overrides();

    my $cobrand = $c->cobrand;

    # append the cobrand templates to the include path
    $c->stash->{additional_template_paths} = $cobrand->path_to_web_templates;

    # work out which language to use
    my $lang_override = $c->get_override('lang');
    my $host          = $c->req->uri->host;
    my $lang =
        $lang_override ? $lang_override
      : $host =~ /^(..)\./ ? $1
      : undef;
    $lang = 'en-gb' if $lang && $lang eq 'en';

    # set the language and the translation file to use - store it on stash
    my $set_lang = $cobrand->set_lang_and_domain(
        $lang,                                       # language
        1,                                           # return unicode
        FixMyStreet->path_to('locale')->stringify    # use locale directory
    );
    $c->stash->{lang_code} = $set_lang;

    # debug
    $c->log->debug( sprintf "Set lang to '%s' and cobrand to '%s'",
        $set_lang, $cobrand->moniker );

    $c->stash->{site_name} = Utils::trim_text($c->render_fragment('site-name.html'));

    $c->model('DB::Problem')->set_restriction( $cobrand->site_key() );

    Memcached::set_namespace( FixMyStreet->config('FMS_DB_NAME') . ":" );

    FixMyStreet::Map::set_map_class( $cobrand->map_type || $c->get_param('map_override') );

    unless ( FixMyStreet->config('MAPIT_URL') ) {
        my $port = $c->req->uri->port;
        $host = "$host:$port" unless $port == 80;
        mySociety::MaPit::configure( "http://$host/fakemapit/" );
    }

    # XXX Put in cobrand / do properly
    if ($c->cobrand->moniker eq 'zurich') {
        FixMyStreet::DB::Result::Problem->visible_states_add('unconfirmed');
        FixMyStreet::DB::Result::Problem->visible_states_remove('investigating');
    }

    if (FixMyStreet->test_mode) {
        # Is there a better way of altering $c->config that may have
        # override_config involved?
        $c->setup_finished(0);
        $c->config( %{ FixMyStreet->config() } );
        $c->setup_finished(1);
    }

    return $c;
}

=head2 setup_dev_overrides

    $c->setup_dev_overrides();

This is only run if STAGING_SITE is true.

It is intended as an easy way to change the cobrand, language, map etc etc etc
without having to muck around with domain names and so on. The overrides are set
by passing _override_xxx parameters in the query. The values and stored in the
session and are used in preference to the defaults.

All overrides can be easily cleared by setting the _override_clear_all parameter
to true.

=cut

sub setup_dev_overrides {
    my $c = shift;

    # If not on STAGING_SITE bail out
    return unless $c->config->{STAGING_SITE};

    # Extract all the _override_xxx parameters
    my %params = %{ $c->req->parameters };
    delete $params{$_} for grep { !m{^_override_} } keys %params;

    # stop if there is nothing to add
    return 1 unless scalar keys %params;

    # Check to see if we should clear all
    if ( $params{_override_clear_all} ) {
        delete $c->session->{overrides};
        return;
    }

    # check for all the other _override params and set their values
    my $overrides = $c->session->{overrides} ||= {};
    foreach my $raw_key ( keys %params ) {
        my ($key) = $raw_key =~ m{^_override_(.*)$};
        $overrides->{$key} = $params{$raw_key};
    }

    return $overrides;
}

=head2 get_override

    $value = $c->get_override( 'cobrand_moniker' );

Checks the overrides for the value given and returns it if found, undef if not.

Always returns undef unless on a staging site (avoids autovivifying overrides
hash in session and so creating a session for all users).

=cut

sub get_override {
    my ( $c, $key ) = @_;
    return unless $c->config->{STAGING_SITE};
    return $c->session->{overrides}->{$key};
}

=head2 send_email

    $email_sent = $c->send_email( 'email_template.txt', $extra_stash_values );

Send an email by filling in the given template with values in the stash.

You can specify extra values to those already in the stash by passing a hashref
as the second argument.

The stash (or extra_stash_values) keys 'to', 'from' and 'subject' are used to
set those fields in the email if they are present.

If a 'from' is not specified then the default from the config is used.

=cut

sub send_email {
    my $c                  = shift;
    my $template           = shift;
    my $extra_stash_values = shift || {};

    my $sender = $c->config->{DO_NOT_REPLY_EMAIL};
    my $sender_name = $c->cobrand->contact_name;

    # create the vars to pass to the email template
    my $vars = {
        from => [ $sender, _($sender_name) ],
        %{ $c->stash },
        %$extra_stash_values,
        additional_template_paths => [
            FixMyStreet->path_to( 'templates', 'email', $c->cobrand->moniker, $c->stash->{lang_code} )->stringify,
            FixMyStreet->path_to( 'templates', 'email', $c->cobrand->moniker )->stringify,
        ]
    };

    return if FixMyStreet::Email::is_abuser($c->model('DB')->schema, $vars->{to});

    # render the template
    my $content = $c->view('Email')->render( $c, $template, $vars );

    # create an email - will parse headers out of content
    my $email = Email::Simple->new($content);
    $email->header_set( 'Subject', $vars->{subject} ) if $vars->{subject};
    $email->header_set( 'Reply-To', $vars->{'Reply-To'} ) if $vars->{'Reply-To'};

    $email->header_set( 'Message-ID', sprintf('<fms-%s-%s@%s>',
        time(), unpack('h*', random_bytes(5, 1)), $c->config->{EMAIL_DOMAIN}
    ) );

    # pass the email into mySociety::Email to construct the on the wire 7bit
    # format - this should probably happen in the transport instead but hohum.
    my $email_text = mySociety::Locale::in_gb_locale { mySociety::Email::construct_email(
        {
            _template_ => $email->body,    # will get line wrapped
            _parameters_ => {},
            _line_indent => '',
            From => $vars->{from},
            To => $vars->{to},
            $email->header_pairs
        }
    ) };

    if (my $attachments = $extra_stash_values->{attachments}) {
        $email_text = FixMyStreet::Email::munge_attachments($email_text, $attachments);
    }

    # send the email
    $c->model('EmailSend')->send($email_text);

    return $email;
}

=head2 uri_with

    $uri = $c->uri_with( ... );

Simply forwards on to $c->req->uri_with - this is a common typo I make!

=cut

sub uri_with {
    my $c = shift;
    return $c->req->uri_with(@_);
}

=head2 uri_for

    $uri = $c->uri_for( ... );

Like C<uri_for> except that it passes the uri to the cobrand to be altered if
needed.

=cut

sub uri_for {
    my $c    = shift;
    my @args = @_;

    my $uri = $c->next::method(@args);

    my $cobranded_uri = $c->cobrand->uri($uri);

    # note that the returned uri may be a string not an object (eg cities)
    return $cobranded_uri;
}

=head2 uri_for_email

    $uri = $c->uri_for_email( ... );

Like C<uri_for> except that it checks the cobrand for an email specific url base
and uses that.

=cut

sub uri_for_email {
    my $c = shift;

    my $normal_uri = $c->uri_for(@_)->absolute;
    my $base       = $c->cobrand->base_url_with_lang;

    my $email_uri = $base . $normal_uri->path_query;

    return URI->new($email_uri);
}

sub finalize {
    my $c = shift;
    $c->next::method(@_);

    # cobrand holds on to a reference to $c so we want to 
    # get git rid of this to stop circular references and
    # memory leaks
    delete $c->stash->{cobrand};
}

=head2 render_fragment

If a page needs to render a template fragment internally (e.g. for an Ajax
call), use this method.

=cut

sub render_fragment {
    my ($c, $template, $vars) = @_;
    $vars->{additional_template_paths} = $c->cobrand->path_to_web_templates
        if $vars;
    $c->view('Web')->render($c, $template, $vars);
}

=head2 get_param

    $param = $c->get_param('name');

Return the parameter passed in the request, or undef if not present. Like
req->param() in a scalar context, this will return the first parameter if
multiple were provided; unlike req->param it will always return a scalar,
never a list, in order to avoid possible security issues.

=cut

sub get_param {
    my ($c, $param) = @_;
    my $value = $c->req->params->{$param};
    return $value->[0] if ref $value;
    return $value;
}

=head2 get_param_list

    @params = $c->get_param_list('name');

Return the parameters passed in the request, as a list. This will always return
a list, with an empty list if no parameter is present.

=cut

sub get_param_list {
    my ($c, $param) = @_;
    my $value = $c->req->params->{$param};
    return @$value if ref $value;
    return ($value) if defined $value;
    return ();
}

=head2 set_param

    $c->set_param('name', 'My Name');

Sets the query parameter to the passed variable.

=cut

sub set_param {
    my ($c, $param, $value) = @_;
    $c->req->params->{$param} = $value;
}

=head1 SEE ALSO

L<FixMyStreet::App::Controller::Root>, L<Catalyst>

=cut

1;
