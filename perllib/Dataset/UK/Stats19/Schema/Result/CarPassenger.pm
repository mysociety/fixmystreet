package Dataset::UK::Stats19::Schema::Result::CarPassenger;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('car_passenger');

__PACKAGE__->subclass;

1;
