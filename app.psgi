use strict;
use warnings;

use FixMyStreet::App;
use Plack::Builder;
use Catalyst::Utils;

my $app = FixMyStreet::App->apply_default_middlewares(FixMyStreet::App->psgi_app);

builder {
    enable 'Debug', panels => [ qw(Parameters Response DBIC::QueryLog CatalystLog Timer Memory FixMyStreet::Template LWP) ]
        if Catalyst::Utils::env_value( 'FixMyStreet::App', 'DEBUG' );

    $app;
};
