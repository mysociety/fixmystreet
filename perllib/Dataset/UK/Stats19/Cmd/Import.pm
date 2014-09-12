package Dataset::UK::Stats19::Cmd::Import;
use Moo;
use MooX::Cmd;
use Path::Tiny;
use Text::CSV_XS;
use File::BOM;
use List::MoreUtils 'zip';
use mySociety::MaPit;
use feature 'say';

has cobrand => (
    is => 'lazy',
    default => sub { FixMyStreet::Cobrand::Smidsy->new },
);

use FixMyStreet;
use FixMyStreet::App;

sub _get_label {
    my $obj = shift or return 'None';
    return $obj->label;
}

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

    my $problem_rs = FixMyStreet::App->model('DB::Problem');
    my %bodies = map { $_->area_id => 1 } FixMyStreet::App->model('DB::Body')->all;

    while (my $v = $vehicles->next) {
        my $accident = $v->accident;
        next unless $accident->accident_index;
        next unless $accident->date;
        next unless $accident->latitude;
        next unless $accident->longitude;
        my $text = _get_description($accident);

        my @areas = $self->get_areas($accident->latitude, $accident->longitude);
        my $bodies_str = 

        say "====================";
        say $text;

        my $problem = $problem_rs->new(
            {
                postcode     => 'EH99 1SP',
                latitude     => '51.5016605453401',
                longitude    => '-0.142497580865087',
                areas        => 1,
                title        => '',
                detail       => '',
                used_map     => 1,
                user_id      => 1,
                name         => '',
                state        => 'confirmed',
                service      => '',
                cobrand      => 'default',
                cobrand_data => '',
            }
        );
    }
    say $vehicles->count;

}

sub _get_description {
    my $accident = shift;

    my $text = join "\n",
        (sprintf 'ID: %s (%s) - %s', 
            $accident->accident_index,
            $accident->date,
            _get_label($accident->accident_severity)),
        '',
        # (sprintf 'Long: %s, Lat: %s', $accident->longitude, $accident->latitude),
        (sprintf 'Local authority district: %s', _get_label($accident->local_authority_district)),
        (sprintf 'On: %s%s (%s) (%smph)', 
            _get_label($accident->road_1_class), 
            $accident->road_1_number,
            _get_label($accident->road_type), 
            $accident->speed_limit),
        $accident->road_2_number ?
            (sprintf 'Junction with: %s%s (%s / %s)',
                _get_label($accident->road_2_class), 
                $accident->road_2_number,
                _get_label($accident->junction_control),
                _get_label($accident->junction_detail)) : (),
        (sprintf 'Conditions: %s / %s / %s / %s / %s', 
            _get_label($accident->light_conditions),
            _get_label($accident->weather_conditions),
            _get_label($accident->road_surface_conditions),
            _get_label($accident->special_conditions_at_site),
            _get_label($accident->carriageway_hazards)),
        (map {
            my $vehicle = $_;
            (sprintf "\nVehicle %s (%s) %s",
                $vehicle->vehicle_reference,
                _get_label($vehicle->vehicle_type),
                _get_label($vehicle->vehicle_manoeuvre)),
            (sprintf "    Driver %s %s",
                _get_label($vehicle->age_band_of_driver),
                _get_label($vehicle->sex_of_driver)),
            (map {
                my $casualty = $_;
                sprintf "    * Casualty %s (%s %s - %s)", 
                    $casualty->casualty_reference,
                    _get_label($casualty->age_band_of_casualty),
                    _get_label($casualty->sex_of_casualty),
                    _get_label($casualty->casualty_severity)
             } $vehicle->casualties->all)
        } $accident->vehicles->all)
}

sub get_areas {
    my ($self, $latitude, $longitude) = @_;

    # cargo culted from FixMyStreet/App/Controller/Council.pm load_and_check_areas
    my $short_latitude  = Utils::truncate_coordinate($latitude);
    my $short_longitude = Utils::truncate_coordinate($longitude);

    my %area_types = map { $_ => 1 } @{ $self->cobrand->area_types };
    my $all_areas = mySociety::MaPit::call(
        'point',
        "4326/$short_longitude,$short_latitude"
    );
    $all_areas = {
        map { $_ => $all_areas->{$_} }
        grep { $area_types{ $all_areas->{$_}->{type} } }
        keys %$all_areas
    };

    return keys %$all_areas;
}

1;
