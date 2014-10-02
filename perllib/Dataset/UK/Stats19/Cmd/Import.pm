package Dataset::UK::Stats19::Cmd::Import;
use Moo;
use MooX::Cmd;
use Path::Tiny;
use Text::CSV_XS;
use File::BOM;
use List::MoreUtils 'zip';
use List::Util 'first';
use mySociety::MaPit;
use feature 'say';

has cobrand => (
    is => 'lazy',
    default => sub { FixMyStreet::Cobrand::Smidsy->new },
);

has user => (
    is => 'lazy',
    default => sub { FixMyStreet::App->model('DB::User')->find_or_create({
                email => 'hakim+smidsy@mysociety.org', name => 'Stats19 Importer'
            }) },
);

use FixMyStreet;
use FixMyStreet::App;

sub _get_label {
    my $obj = shift or return (shift || 'None');
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
    my %areas = map { $_->area_id => 1 } FixMyStreet::App->model('DB::BodyArea')->all;

    my $user_id = $self->user->id;

    my $failed = 0;

    while (my $v = $vehicles->next) {
        my $accident = $v->accident;
        next unless $accident->accident_index;

        if ($problem_rs->search({ external_id => $accident->accident_index })->count) {
            say sprintf "Index %s already exists!", $accident->accident_index;
	    next;
        }

        next unless $accident->date;
        next unless $accident->latitude;
        next unless $accident->longitude;
        my $text = _get_description($accident);

        my @areas = $self->get_areas($accident->latitude, $accident->longitude)
            or do {
                warn "Couldn't fetch areas: MaPit error?";
                $failed++;
                next;
            };

        my $bodies_str = ( first { $areas{$_} } @areas ) || '';
        my $areas = join ',', '', @areas, ''; # note empty strings at beginning/end

        say "====================";
        say $text;

        my @participants = $accident->grouped_participants;
        my $category = # e.g. "pedestrian-serious"
            $participants[-1][0] # e.g. code of highest priority participant
            . '-' 
            . lc(_get_label($accident->accident_severity));

        my $participants_string = do {
            my @ps = map {
                my ($type, $count) = @$_;
                $count > 1 ? "$count ${type}s" : "a $type";
            } @participants;
            if (@ps > 2) {
                $ps[-1] = 'and ' . $ps[-1]; # oxford comma ftw
                join ', ' => @ps;
            }
            else {
                join ' and ', @ps;
            }
        };

        my $extra = {
            road_type => _get_road_1_string($accident),
            severity => _get_severity_percent(_get_label($accident->accident_severity)),
            incident_date => $accident->date->strftime('%Y-%m-%d'),
            incident_time => $accident->date->strftime('%H:%M'),
        };

        my $title = sprintf '%s incident involving %s',
                    _get_label($accident->accident_severity),
                    $participants_string;

        my $problem = $problem_rs->create(
            {
		external_id  => $accident->accident_index,
                postcode     => '',
                latitude     => $accident->latitude,
                longitude    => $accident->longitude,
                bodies_str   => $bodies_str,
                areas        => $areas,
                title        => $title,
                detail       => $text,
                used_map     => 1, # to allow pin to be shown
                user_id      => $user_id,
                name         => 'Stats19 import',
                state        => 'confirmed',
                service      => '',
                cobrand      => $self->cobrand->moniker,
                cobrand_data => '',
                category     => $category,
                anonymous    => 0,
                created      => $accident->date,
                confirmed    => $accident->date,
                whensent     => $accident->date, # prevent imported stats19 data from getting sent again
                extra        => $extra,
            });
        say sprintf 'Created Problem #%d', $problem->id;
    }
    say $vehicles->count;

    say sprintf "Failed: %d", $failed if $failed;

}

sub _get_severity_percent {
    # TODO refactor into Cobrand
    my $label = shift;
    return { 
        'Slight' => 30,
        'Serious' => 75,
        'Fatal' => 90,
    }->{$label} || 10;
}

sub _get_description {
    my $accident = shift;

    my $text = join "\n",
        (sprintf 'Stats19 record: %s', $accident->accident_index),
        (sprintf 'Local authority district: %s', _get_label($accident->local_authority_district)),
        (sprintf 'On: %s', _get_road_1_string($accident)),
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
                _get_label($vehicle->age_band_of_driver, 'Unknown'),
                _get_label($vehicle->sex_of_driver, 'Unknown')),
            (map {
                my $casualty = $_;
                sprintf "    * Casualty %s (%s%s %s - %s)", 
                    $casualty->casualty_reference,
                    $casualty->is_pedestrian ? 'Pedestrian - ' : '',
                    _get_label($casualty->age_band_of_casualty, 'Unknown'),
                    _get_label($casualty->sex_of_casualty, 'Unknown'),
                    _get_label($casualty->casualty_severity)
             } $vehicle->casualties->all)
        } $accident->vehicles->all)
}

sub _get_road_1_string {
    my $accident = shift;
    sprintf '%s%s (%s) (%smph)', 
        _get_label($accident->road_1_class), 
        $accident->road_1_number,
        _get_label($accident->road_type), 
        $accident->speed_limit;
}

sub _get_participants {
    my $accident = shift;

    return join ', ', 
        sort { 
            (_vehicle_priority($a) <=> _vehicle_priority($b)) 
            || 
            ($a cmp $b)
        } 
        $accident->participants;
}

sub _vehicle_priority {
    my $veh = shift;
    return 0 if $veh =~/Pedal/;
}

sub get_areas {
    my ($self, $latitude, $longitude) = @_;

    # cargo culted from FixMyStreet/App/Controller/Council.pm load_and_check_areas
    my $short_latitude  = Utils::truncate_coordinate($latitude);
    my $short_longitude = Utils::truncate_coordinate($longitude);

    my %area_types = map { $_ => 1 } @{ $self->cobrand->area_types };

    my $all_areas = eval {
        mySociety::MaPit::call(
            'point',
            "4326/$short_longitude,$short_latitude"
        )
    } or return;

    $all_areas = {
        map { $_ => $all_areas->{$_} }
        grep { $area_types{ $all_areas->{$_}->{type} } }
        keys %$all_areas
    };

    return keys %$all_areas;
}

1;
