package Dataset::UK::Stats19::Schema::Result::BusPassenger;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('bus_passenger');

__PACKAGE__->subclass;

1;
