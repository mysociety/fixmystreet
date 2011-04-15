package FixMyStreet::App;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;
use FixMyStreet;
use FixMyStreet::Cobrand;
use Memcached;
use Problems;
use mySociety::Email;
use FixMyStreet::Map;
use FixMyStreet::FakeQ;

use Catalyst (
    'Static::Simple',    #
    'Unicode',
    'Session',
    'Session::Store::DBIC',
    'Session::State::Cookie',    # FIXME - we're using our own override atm
    'Authentication',
);

extends 'Catalyst';

our $VERSION = '0.01';

__PACKAGE__->config(

    # get the config from the core object
    %{ FixMyStreet->config() },

    name => 'FixMyStreet::App',

    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,

    # Some generic stuff
    default_view => 'Web',

    # Serve anything in web dir that is not a .cgi script
    static => {    #
        include_path      => [ FixMyStreet->path_to("web") . "" ],
        ignore_extensions => ['cgi'],
    },

    'Plugin::Session' => {    # Catalyst::Plugin::Session::Store::DBIC
        dbic_class => 'DB::Session',
        expires    => 3600 * 24 * 7 * 6,    # 6 months
    },

    'Plugin::Authentication' => {
        default_realm => 'default',
        default       => {
            credential => {    # Catalyst::Authentication::Credential::Password
                class              => 'Password',
                password_field     => 'password',
                password_type      => 'hashed',
                password_hash_type => 'SHA-1',
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

# set up DB handle for old code
FixMyStreet->configure_mysociety_dbhandle;

# disable debug logging unless in debaug mode
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

    my $cobrand = $cobrand_class->new( { request => $c->req } );

    # create the cobrand explicitly passing in the site. Avoids the chicken and
    # egg situation where one needs to be created first. Should disappear when
    # all instances of the old '$q' are gone.
    $cobrand->fake_q( $c->fake_q( { site => $cobrand->moniker } ) );

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
    $c->stash->{additional_template_paths} =
      [ $cobrand->path_to_web_templates->stringify ]
      unless $cobrand->is_default;

    # work out which language to use
    my $lang_override = $c->get_override('lang');
    my $host          = $c->req->uri->host;
    my $lang =
        $lang_override ? $lang_override
      : $host =~ /^en\./ ? 'en-gb'
      : $host =~ /cy/    ? 'cy'
      :                    undef;

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

    Problems::set_site_restriction_with_cobrand_object($cobrand);

    Memcached::set_namespace( FixMyStreet->config('BCI_DB_NAME') . ":" );

    FixMyStreet::Map::set_map_class( $c->request->param('map') );

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

    # create the vars to pass to the email template
    my $vars = {
        from => FixMyStreet->config('CONTACT_EMAIL'),
        %{ $c->stash },
        %$extra_stash_values,
        additional_template_paths =>
          [ $c->cobrand->path_to_email_templates->stringify ]
    };

    # render the template
    my $content = $c->view('Email')->render( $c, $template, $vars );

    # create an email - will parse headers out of content
    my $email = Email::Simple->new($content);
    $email->header_set( ucfirst($_), $vars->{$_} )
      for grep { $vars->{$_} } qw( to from subject);

    # pass the email into mySociety::Email to construct the on the wire 7bit
    # format - this should probably happen in the transport instead but hohum.
    my $email_text = mySociety::Email::construct_email(
        {
            _unwrapped_body_ => $email->body,    # will get line wrapped
            $email->header_pairs
        }
    );

    # send the email
    $c->model('EmailSend')->send($email_text);

    return $email;
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

    # Currently the cobrand expect and return the url as a string.
    my $cobranded_uri = $c->cobrand->url( $uri->as_string );

    # check to see if the returned string looks like a url (cities does not)
    return $cobranded_uri =~ m{^https?://}
      ? URI->new($cobranded_uri)
      : $cobranded_uri;
}

=head2 uri_for_email

    $uri = $c->uri_for_email( ... );

Like C<uri_for> except that it checks the cobrand for an email specific url base
and uses that.

=cut

sub uri_for_email {
    my $c    = shift;
    my @args = @_;

    my $normal_uri = $c->uri_for(@_);
    my $base       = $c->cobrand->base_url_for_emails();

    my $email_uri = $base . $normal_uri->path_query;

    return URI->new($email_uri);
}

=head2 fake_q

    $q = $c->fake_q();                                   # normal usage
    $q = $c->fake_q( { site => 'cobrand_moniker' } );    # when creating

Returns a faked up object that behaves as the old code expects the old '$q' to
behave. Object is cached for the request. See L<FixMyStreet::FakeQ> for more
details.

The first time fake_q is called you need to pass in 'site' explicitly. This
should normally be done automatically when the cobrand is first loaded.

=cut

sub fake_q {
    my $c    = shift;
    my $args = shift;

    return $c->stash->{fakeq}    #
      ||= $c->_get_fake_q($args);
}

sub _get_fake_q {
    my $c = shift;
    my $args = shift || {};

    $args->{params} ||= $c->req->parameters;

    return FixMyStreet::FakeQ->new($args);
}

=head1 SEE ALSO

L<FixMyStreet::App::Controller::Root>, L<Catalyst>

=cut

1;
