package Dataset::UK::Stats19::Schema::Result::Vehicle;

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime");
__PACKAGE__->table("vehicles");
__PACKAGE__->add_columns(
    id => {
        data_type         => "integer",
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    accident_index => {
    },
    vehicle_reference => {},
    vehicle_type => {},
    towing_and_articulation => {},
    vehicle_manoeuvre => {},
    vehicle_location_restricted_lane => {},
    junction_location => {},
    skidding_and_overturning => {},
    hit_object_in_carriageway => {},
    vehicle_leaving_carriageway => {},
    hit_object_off_carriageway => {},
    point_of_impact_1 => {},
    was_vehicle_left_hand_drive => {},
    journey_purpose_of_driver => {},
    sex_of_driver => {},
    age_band_of_driver => {},
    engine_capacity_cc => {},
    propulsion_code => {},
    age_of_vehicle => {},
    driver_imd_decile => {},
    driver_home_area_type => {},
);
__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
  "accident",
  "Dataset::UK::Stats19::Schema::Result::Accident",
  { accident_index => "accident_index" },
);

__PACKAGE__->belongs_to(
  "vehicle_type_obj",
  "Dataset::UK::Stats19::Schema::Result::VehicleType",
  { 'foreign.code' => 'self.vehicle_type' },
);

1;
