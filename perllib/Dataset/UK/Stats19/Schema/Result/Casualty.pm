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
    casualty_class_code => {}, # CasualtyClass
    sex_of_casualty_code => {}, # SexOfCasualty
    age_band_of_casualty_code => {}, # AgeBand
    casualty_severity_code => {}, # CasualtySeverity
    pedestrian_location_code => {}, # PedestrianLocation
    pedestrian_movement_code => {}, # PedestrianMovement
    car_passenger_code => {}, # CarPassenger
    bus_or_coach_passenger_code => {}, # BusPassenger
    pedestrian_road_maintenance_worker_code => {}, # PedestrianRoadMaintenanceWorker
    casualty_type_code => {}, # CasualtyType
    casualty_home_area_type_code => {}, # HomeAreaType
);

__PACKAGE__->belongs_to(
  "accident",
  "Dataset::UK::Stats19::Schema::Result::Accident",
  { accident_index => "accident_index" },
);

__PACKAGE__->belongs_to(
  "casualty_class",
  "Dataset::UK::Stats19::Schema::Result::CasualtyClass",
  { code => "casualty_class_code" },
);

__PACKAGE__->belongs_to(
  "sex_of_casualty",
  "Dataset::UK::Stats19::Schema::Result::SexOfCasualty",
  { code => "sex_of_casualty_code" },
);

__PACKAGE__->belongs_to(
  "age_band_of_casualty",
  "Dataset::UK::Stats19::Schema::Result::AgeBand",
  { code => "age_band_of_casualty_code" },
);

__PACKAGE__->belongs_to(
  "casualty_severity",
  "Dataset::UK::Stats19::Schema::Result::CasualtySeverity",
  { code => "casualty_severity_code" },
);

__PACKAGE__->belongs_to(
  "pedestrian_location",
  "Dataset::UK::Stats19::Schema::Result::PedestrianLocation",
  { code => "pedestrian_location_code" },
);

__PACKAGE__->belongs_to(
  "pedestrian_movement",
  "Dataset::UK::Stats19::Schema::Result::PedestrianMovement",
  { code => "pedestrian_movement_code" },
);

__PACKAGE__->belongs_to(
  "car_passenger",
  "Dataset::UK::Stats19::Schema::Result::CarPassenger",
  { code => "car_passenger_code" },
);

__PACKAGE__->belongs_to(
  "bus_or_coach_passenger",
  "Dataset::UK::Stats19::Schema::Result::BusPassenger",
  { code => "bus_or_coach_passenger_code" },
);

__PACKAGE__->belongs_to(
  "pedestrian_road_maintenance_worker",
  "Dataset::UK::Stats19::Schema::Result::PedestrianRoadMaintenanceWorker",
  { code => "pedestrian_road_maintenance_worker_code" },
);

__PACKAGE__->belongs_to(
  "casualty_type",
  "Dataset::UK::Stats19::Schema::Result::CasualtyType",
  { code => "casualty_type_code" },
);

__PACKAGE__->belongs_to(
  "casualty_home_area_type",
  "Dataset::UK::Stats19::Schema::Result::HomeAreaType",
  { code => "casualty_home_area_type_code" },
);

__PACKAGE__->set_primary_key("id");

sub is_pedestrian {
    # 0 is not a pedestrian
    # -1 is invalid record
    # so all positive numbers represent a pedestrian

    my $self = shift;
    my $pedestrian_location_code = $self->pedestrian_location_code;
    return $pedestrian_location_code > 0;
}

1;
