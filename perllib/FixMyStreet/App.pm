package FixMyStreet::App;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

use Catalyst qw/
  ConfigLoader
  Static::Simple
  /;

extends 'Catalyst';

our $VERSION = '0.01';

BEGIN {
    use mySociety::Config;
    mySociety::Config::set_file( __PACKAGE__->path_to("conf/general") );
}

# Configure the application.
#
# Note that settings in fixmystreet_app.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    %{ mySociety::Config::get_list() },

    name => 'FixMyStreet::App',

    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,

    # Serve anything in web dir that is not a .cgi script
    static => {    #
        include_path      => [ __PACKAGE__->path_to("web") . "" ],
        ignore_extensions => ['cgi'],
    }
);

# Start the application
__PACKAGE__->setup();

=head1 NAME

FixMyStreet::App - Catalyst based application

=head1 SYNOPSIS

    script/fixmystreet_app_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<FixMyStreet::App::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Edmund von der Burg,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
