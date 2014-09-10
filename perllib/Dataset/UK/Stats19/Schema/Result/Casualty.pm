package Dataset::UK::Stats19::Schema::Result::Casualty;

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime");
__PACKAGE__->table("casualties");
__PACKAGE__->add_columns(
    id => {
        data_type         => "integer",
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    accident_index => {
    },
    vehicle_reference => {},
    casualty_reference => {},
    casualty_class => {},
    sex_of_casualty => {},
    age_band_of_casualty => {},
    casualty_severity => {},
    pedestrian_location => {},
    pedestrian_movement => {},
    car_passenger => {},
    bus_or_coach_passenger => {},
    pedestrian_road_maintenance_worker => {},
    casualty_type => {},
    casualty_home_area_type => {},
);

__PACKAGE__->belongs_to(
  "accident",
  "Dataset::UK::Stats19::Schema::Result::Accident",
  { accident_index => "accident_index" },
);

__PACKAGE__->set_primary_key("id");

1;
