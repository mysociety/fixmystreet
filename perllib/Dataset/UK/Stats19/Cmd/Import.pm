package Dataset::UK::Stats19::Cmd::Import;
use Moo;
use MooX::Cmd;
use Path::Tiny;
use Text::CSV_XS;
use File::BOM;
use List::MoreUtils 'zip';
use feature 'say';

sub execute {
    my ($self, $args, $chain) = @_;
    my ($stats19) = @{ $chain };

    my $db = $stats19->db;

    my $bike = $db->resultset('VehicleType')->find({ label => 'Pedal cycle' });

    my $vehicles = $db->resultset('Vehicle')->search(
        { vehicle_type_code => $bike->code },
        { group_by => 'me.accident_index',
          prefetch => 'accident' },
    );

    while (my $v = $vehicles->next) {
        say '======================';
        my $accident = $v->accident;
        say sprintf 'ID: %s (%s) - %s', 
            $accident->accident_index,
            $accident->date,
            $accident->accident_severity->label;
        say sprintf 'Long: %s, Lat: %s', $accident->longitude, $accident->latitude;
        say sprintf 'Local authority district: %s', $accident->local_authority_district->label;
        # say sprintf 'Local authority highway %s', $accident->local_authority_highway->label;
        say sprintf 'On: %s%s (%s) (%smph)', $accident->road_1_class->label, $accident->road_1_number,
            $accident->road_type->label, $accident->speed_limit;
        say sprintf 'Junction with: %s%s (%s / %s)',
            $accident->road_2_class->label, $accident->road_2_number,
            $accident->junction_control->label, $accident->junction_detail->label
            if $accident->road_2_number;
        # say sprintf 'Pedestrian crossing (Human Control): %s', $accident->pedestrian_crossing_human_control->label;
        say sprintf 'Conditions: %s / %s / %s / %s / %s', 
            $accident->light_conditions->label,
            $accident->weather_conditions->label,
            $accident->road_surface_conditions->label,
            $accident->special_conditions_at_site->label,
            $accident->carriageway_hazards->label;

        # say sprintf 'Police force: %s', $accident->police_force->label;

        for my $vehicle ($accident->vehicles->all) {
            say sprintf "=== Vehicle %s (%s) %s", $vehicle->vehicle_reference,
                $vehicle->vehicle_type->label,
                $vehicle->vehicle_manoeuvre->label;

            eval { say sprintf "    Driver %s %s", $vehicle->age_band_of_driver->label,
                $vehicle->sex_of_driver->label };

            for my $casualty ($vehicle->casualties->all) {
                say sprintf "     * Casualty %s (%s %s - %s)", 
                    $casualty->casualty_reference,
                    $casualty->age_band_of_casualty->label,
                    $casualty->sex_of_casualty->label,
                    $casualty->casualty_severity->label;
            }
            # say sprintf "    Location: %s", $vehicle->vehicle_location_restricted_lane->label;
            # say sprintf "    Skidding?: %s", $vehicle->skidding_and_overturning->label;
            # say sprintf "    Hit object in?: %s", $vehicle->hit_object_in_carriageway->label;
            # say sprintf "    Hit object off?: %s", $vehicle->hit_object_off_carriageway->label;

        }
    }

    say $vehicles->count;

}

1;
