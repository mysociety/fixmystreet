package Dataset::UK::Stats19::Schema::Result::VehiclePropulsionCode;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('vehicle_propulsion_code');

__PACKAGE__->subclass;

1;
