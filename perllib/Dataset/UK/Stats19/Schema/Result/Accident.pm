package Dataset::UK::Stats19::Schema::Result::Accident;

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime");
__PACKAGE__->table("accidents");
__PACKAGE__->add_columns(
    id => {
        data_type         => "integer",
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    accident_index => {
    },
    location_easting_osgr => {
    },
    location_northing_osgr => {
    },
    longitude => {
    },
    latitude => {
    },
    police_force => {
    },
    accident_severity => {
    },
    number_of_vehicles => {
    },
    number_of_casualties => {
    },
    date => {
    },
    day_of_week => {
    },
    time => {
    },
    local_authority_district => {
    },
    local_authority_highway => {
    },
    road_1_class => {
    },
    road_1_number => {
    },
    road_type => {
    },
    speed_limit => {
    },
    junction_detail => {
    },
    junction_control => {
    },
    road_2_class => {
    },
    road_2_number => {
    },
    pedestrian_crossing_human_control => {
    },
    pedestrian_crossing_physical_facilities => {
    },
    light_conditions => {
    },
    weather_conditions => {
    },
    road_surface_conditions => {
    },
    special_conditions_at_site => {
    },
    carriageway_hazards => {
    },
    urban_or_rural_area => {
    },
    did_police_officer_attend_scene_of_accident => {
    },
    lsoa_of_accident_location => {
    }
);
__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many(
  "casualties",
  "Dataset::UK::Stats19::Schema::Result::Casualty",
  { accident_index => "accident_index" },
);

__PACKAGE__->has_many(
  "vehicles",
  "Dataset::UK::Stats19::Schema::Result::Vehicle",
  { accident_index => "accident_index" },
);

1;
