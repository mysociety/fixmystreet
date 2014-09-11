package Dataset::UK::Stats19::Schema::Result::WasVehicleLeftHandDrive;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('was_vehicle_left_hand_drive');

__PACKAGE__->subclass;

1;
