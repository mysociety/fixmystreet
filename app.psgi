use strict;
use warnings;

use FixMyStreet::App;

my $app = FixMyStreet::App->apply_default_middlewares(FixMyStreet::App->psgi_app);
$app;

