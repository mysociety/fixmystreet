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
    vehicle_type_code => {}, # VehicleType
    towing_and_articulation_code => {},
    vehicle_manoeuvre_code => {},
    vehicle_location_restricted_lane_code => {},
    junction_location_code => {},
    skidding_and_overturning_code => {},
    hit_object_in_carriageway_code => {},
    vehicle_leaving_carriageway_code => {},
    hit_object_off_carriageway_code => {},
    point_of_impact_1_code => {},
    was_vehicle_left_hand_drive_code => {},
    journey_purpose_of_driver_code => {},
    sex_of_driver_code => {},
    age_band_of_driver_code => {},
    engine_capacity_cc => {},
    propulsion_code => {},
    age_of_vehicle => {},
    driver_imd_decile_code => {},
    driver_home_area_type_code => {},
);
__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
  "accident",
  "Dataset::UK::Stats19::Schema::Result::Accident",
  { accident_index => "accident_index" },
);

__PACKAGE__->belongs_to(
  "vehicle_type",
  "Dataset::UK::Stats19::Schema::Result::VehicleType",
  { 'foreign.code' => 'self.vehicle_type_code' },
);

__PACKAGE__->belongs_to(
  "towing_and_articulation",
  "Dataset::UK::Stats19::Schema::Result::TowingAndArticulation",
  { 'foreign.code' => 'self.towing_and_articulation_code' },
);

__PACKAGE__->belongs_to(
  "vehicle_manoeuvre",
  "Dataset::UK::Stats19::Schema::Result::VehicleManouvre",
  { 'foreign.code' => 'self.vehicle_manoeuvre_code' },
);

__PACKAGE__->belongs_to(
  "vehicle_location_restricted_lane",
  "Dataset::UK::Stats19::Schema::Result::VehicleLocation",
  { 'foreign.code' => 'self.vehicle_location_restricted_lane_code' },
);

__PACKAGE__->belongs_to(
  "junction_location",
  "Dataset::UK::Stats19::Schema::Result::JunctionLocation",
  { 'foreign.code' => 'self.junction_location_code' },
);

__PACKAGE__->belongs_to(
  "skidding_and_overturning",
  "Dataset::UK::Stats19::Schema::Result::SkiddingAndOverturning",
  { 'foreign.code' => 'self.skidding_and_overturning_code' },
);

__PACKAGE__->belongs_to(
  "hit_object_in_carriageway",
  "Dataset::UK::Stats19::Schema::Result::HitObjectInCarriageway",
  { 'foreign.code' => 'self.hit_object_in_carriageway_code' },
);

__PACKAGE__->belongs_to(
  "hit_object_off_carriageway",
  "Dataset::UK::Stats19::Schema::Result::HitObjectOffCarriageway",
  { 'foreign.code' => 'self.hit_object_off_carriageway_code' },
);

__PACKAGE__->belongs_to(
  "vehicle_leaving_carriageway",
  "Dataset::UK::Stats19::Schema::Result::VehicleLeavingCarriageway",
  { 'foreign.code' => 'self.vehicle_leaving_carriageway_code' },
);

__PACKAGE__->belongs_to(
  "point_of_impact_1",
  "Dataset::UK::Stats19::Schema::Result::PointOfImpact1",
  { 'foreign.code' => 'self.point_of_impact_1_code' },
);

__PACKAGE__->belongs_to(
  "was_vehicle_left_hand_drive",
  "Dataset::UK::Stats19::Schema::Result::WasVehicleLeftHandDrive",
  { 'foreign.code' => 'self.was_vehicle_left_hand_drive_code' },
);

__PACKAGE__->belongs_to(
  "journey_purpose_of_driver",
  "Dataset::UK::Stats19::Schema::Result::JourneyPurpose",
  { 'foreign.code' => 'self.journey_purpose_of_driver_code' },
);

__PACKAGE__->belongs_to(
  "sex_of_driver",
  "Dataset::UK::Stats19::Schema::Result::SexOfDriver",
  { 'foreign.code' => 'self.sex_of_driver_code' },
);

__PACKAGE__->belongs_to(
  "age_band_of_driver",
  "Dataset::UK::Stats19::Schema::Result::AgeBand",
  { 'foreign.code' => 'self.age_band_of_driver_code' },
);

__PACKAGE__->belongs_to(
  "driver_imd_decile",
  "Dataset::UK::Stats19::Schema::Result::ImdDecile",
  { 'foreign.code' => 'self.driver_imd_decile_code' },
);

__PACKAGE__->belongs_to(
  "driver_home_area_type",
  "Dataset::UK::Stats19::Schema::Result::HomeAreaType",
  { 'foreign.code' => 'self.driver_home_area_type_code' },
);

__PACKAGE__->has_many(
    'casualties',
  "Dataset::UK::Stats19::Schema::Result::Casualty",
  { 'foreign.accident_index' => 'self.accident_index',
    'foreign.vehicle_reference' => 'self.vehicle_reference', },
);

sub vehicle_short_category {
    my $self = shift;
    my $vehicle_type = $self->vehicle_type->label;
    return 'bicycle' if $vehicle_type =~/Pedal/;
    return 'horse' if $vehicle_type =~/[hH]orse/;
    return 'vehicle';
}

1;
