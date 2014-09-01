package Dataset::UK::Stats19::Schema::Result::PedestrianRoadMaintenanceWorker;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('pedestrian_road_maintenance_worker');

__PACKAGE__->subclass;

1;
