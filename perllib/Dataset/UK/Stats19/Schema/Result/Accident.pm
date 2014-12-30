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
    police_force_code => { # PoliceForce
    },
    accident_severity_code => { # AccidentSeverity
    },
    number_of_vehicles => {
    },
    number_of_casualties => {
    },
    date => {
        data_type => "datetime",
        default_value => '0000-00-00',
        is_nullable => 1,
        datetime_undef_if_invalid => 1
    },
    day_of_week_code => { #DayOfWeek
    },
    time => {
    },
    local_authority_district_code => { # LocalAuthorityDistrict
    },
    local_authority_highway_code => { # LocalAuthorityHighway
    },
    road_1_class_code => { # RoadClass
    },
    road_1_number => {
    },
    road_type_code => { # RoadType
    },
    speed_limit => {
    },
    junction_detail_code => { # JunctionDetail
    },
    junction_control_code => { # JunctionControl
    },
    road_2_class_code => { # RoadClass
    },
    road_2_number => {
    },
    pedestrian_crossing_human_control_code => { # PedCrossHuman
    },
    pedestrian_crossing_physical_facilities_code => { # PedCrossPhysical
    },
    light_conditions_code => { # LightConditions
    },
    weather_conditions_code => { # WeatherConditions
    },
    road_surface_conditions_code => { # RoadSurface
    },
    special_conditions_at_site_code => { # SpecialConditionsAtSite
    },
    carriageway_hazards_code => { # CarriagewayHazards
    },
    urban_or_rural_area_code => { # UrbanRural
    },
    did_police_officer_attend_scene_of_accident_code => { # PoliceOfficerAttend
    },
    lsoa_of_accident_location => {
    }
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint( [ "accident_index" ]);

__PACKAGE__->has_many(
  "casualties",
  "Dataset::UK::Stats19::Schema::Result::Casualty",
  { accident_index => "accident_index" },
);

__PACKAGE__->has_many(
  "vehicles",
  "Dataset::UK::Stats19::Schema::Result::Vehicle",
  { 'foreign.accident_index' => "self.accident_index" },
);

__PACKAGE__->belongs_to(
  "police_force",
  "Dataset::UK::Stats19::Schema::Result::PoliceForce",
  { 'foreign.code' => 'self.police_force_code' },
);

__PACKAGE__->belongs_to(
  "accident_severity",
  "Dataset::UK::Stats19::Schema::Result::AccidentSeverity",
  { 'foreign.code' => 'self.accident_severity_code' },
);

__PACKAGE__->belongs_to(
  "day_of_week",
  "Dataset::UK::Stats19::Schema::Result::DayOfWeek",
  { 'foreign.code' => 'self.day_of_week_code' },
);

__PACKAGE__->belongs_to(
  "local_authority_district",
  "Dataset::UK::Stats19::Schema::Result::LocalAuthorityDistrict",
  { 'foreign.code' => 'self.local_authority_district_code' },
);

__PACKAGE__->belongs_to(
  "local_authority_highway",
  "Dataset::UK::Stats19::Schema::Result::LocalAuthorityHighway",
  { 'foreign.code' => 'self.local_authority_highway_code' },
);

__PACKAGE__->belongs_to(
  "road_1_class",
  "Dataset::UK::Stats19::Schema::Result::RoadClass",
  { 'foreign.code' => 'self.road_1_class_code' },
);

__PACKAGE__->belongs_to(
  "road_2_class",
  "Dataset::UK::Stats19::Schema::Result::RoadClass",
  { 'foreign.code' => 'self.road_2_class_code' },
);

__PACKAGE__->belongs_to(
  "road_type",
  "Dataset::UK::Stats19::Schema::Result::RoadType",
  { 'foreign.code' => 'self.road_type_code' },
);

__PACKAGE__->belongs_to(
  "junction_detail",
  "Dataset::UK::Stats19::Schema::Result::JunctionDetail",
  { 'foreign.code' => 'self.junction_detail_code' },
);

__PACKAGE__->belongs_to(
  "junction_control",
  "Dataset::UK::Stats19::Schema::Result::JunctionControl",
  { 'foreign.code' => 'self.junction_control_code' },
);

__PACKAGE__->belongs_to(
  "pedestrian_crossing_human_control",
  "Dataset::UK::Stats19::Schema::Result::PedCrossHuman",
  { 'foreign.code' => 'self.pedestrian_crossing_human_control_code' },
);

__PACKAGE__->belongs_to(
  "pedestrian_crossing_physical_facilities",
  "Dataset::UK::Stats19::Schema::Result::PedCrossPhysical",
  { 'foreign.code' => 'self.pedestrian_crossing_physical_facilities_code' },
);

__PACKAGE__->belongs_to(
  "light_conditions",
  "Dataset::UK::Stats19::Schema::Result::LightConditions",
  { 'foreign.code' => 'self.light_conditions_code' },
);

__PACKAGE__->belongs_to(
  "weather_conditions",
  "Dataset::UK::Stats19::Schema::Result::WeatherConditions",
  { 'foreign.code' => 'self.weather_conditions_code' },
);

__PACKAGE__->belongs_to(
  "road_surface_conditions",
  "Dataset::UK::Stats19::Schema::Result::RoadSurface",
  { 'foreign.code' => 'self.road_surface_conditions_code' },
);

__PACKAGE__->belongs_to(
  "special_conditions_at_site",
  "Dataset::UK::Stats19::Schema::Result::SpecialConditionsAtSite",
  { 'foreign.code' => 'self.special_conditions_at_site_code' },
);

__PACKAGE__->belongs_to(
  "carriageway_hazards",
  "Dataset::UK::Stats19::Schema::Result::CarriagewayHazards",
  { 'foreign.code' => 'self.carriageway_hazards_code' },
);

__PACKAGE__->belongs_to(
  "urban_or_rural_area",
  "Dataset::UK::Stats19::Schema::Result::UrbanRural",
  { 'foreign.code' => 'self.urban_or_rural_area_code' },
);

__PACKAGE__->belongs_to(
  "did_police_officer_attend_scene_of_accident",
  "Dataset::UK::Stats19::Schema::Result::PoliceOfficerAttend",
  { 'foreign.code' => 'self.did_police_officer_attend_scene_of_accident_code' },
);

=head2 C<participants>

    my @participants = $accident->participants;

    (
        [ 'Car', 'vehicle',  $veh1 ],
        [ 'Pedestrian', 'pedestrian', $veh1 ],
        [ 'Pedal cycle', 'bike', $veh2 ],
    )

Returns a list of tuples C<[ $stats19_description, $short_category, $vehicle_object ]>
of each participant in the crash.  Note that pedestrians are linked to the vehicle that
hit them.

=cut

sub participants {
    my $self = shift;
    return map {
        [ $_->vehicle_type, $_->vehicle_short_category, $_ ],
        map {
            [ 'Pedestrian', 'pedestrian', $_ ]
        }
        grep { 
            $_->is_pedestrian 
        } $_->casualties;
    } $self->vehicles,
}

=head2 C<grouped_participants>

    my @grouped = $accident->grouped_participants;

    (
        [ 'bike' => 1 ],
        [ 'pedestrian' => 1 ],
        [ 'vehicle' => 1 ]
    )

=cut

sub grouped_participants {
    my $self = shift;
    my %priority = (
        bicycle => 0,
        pedestrian => 1,
        vehicle => 2,
        horse => 3,
    );

    my %count;
    for my $p ($self->participants) {
        $count{$p->[1]}++;
    }

    return (
        map [ $_ => $count{$_} ],
        sort { $priority{$a} <=> $priority{$b} } 
        keys %count
    );
}

1;
