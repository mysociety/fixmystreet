package FixMyStreet::App;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;
use FixMyStreet;
use FixMyStreet::Cobrand;
use Memcached;
use Problems;

use Catalyst qw/
  ConfigLoader
  Static::Simple
  /;

extends 'Catalyst';

our $VERSION = '0.01';

# Configure the application.
#
# Note that settings in fixmystreet_app.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(

    # get the config from the core object
    %{ FixMyStreet->config() },

    name => 'FixMyStreet::App',

    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,

    # Serve anything in web dir that is not a .cgi script
    static => {    #
        include_path      => [ FixMyStreet->path_to("web") . "" ],
        ignore_extensions => ['cgi'],
    }
);

# Start the application
__PACKAGE__->setup();

# disable debug logging unless in debaug mode
__PACKAGE__->log->disable('debug') unless __PACKAGE__->debug;

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
    my $c             = shift;
    my $host          = $c->req->uri->host;
    my $cobrand_class = FixMyStreet::Cobrand->get_class_for_host($host);
    return $cobrand_class->new( { request => $c->req } );
}

=head2 setup_cobrand

    $cobrand = $c->setup_cobrand();

Work out which cobrand we should be using. Set the environment correctly - eg
template paths

=cut

sub setup_cobrand {
    my $c       = shift;
    my $cobrand = $c->cobrand;

    # append the cobrand templates to the include path
    $c->stash->{additional_template_paths} =
      [ $cobrand->path_to_web_templates . '' ]
      unless $cobrand->is_default;

    my $host = $c->req->uri->host;
    my $lang =
        $host =~ /^en\./ ? 'en-gb'
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

    return $cobrand;
}

=head1 SEE ALSO

L<FixMyStreet::App::Controller::Root>, L<Catalyst>

=cut

1;
