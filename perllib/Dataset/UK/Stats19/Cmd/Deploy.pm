package Dataset::UK::Stats19::Cmd::Deploy;
use Moo;
use MooX::Cmd;
use Path::Tiny;
use Text::CSV_XS;
use File::BOM;
use List::MoreUtils 'zip';
use DateTime::Format::Strptime;
use feature 'say';

has csv => (
    is => 'lazy',
    default => sub {
        Text::CSV_XS->new({ auto_diag => 1, });
    },
);

sub execute {
    my ($self, $args, $chain) = @_;
    my ($stats19) = @{ $chain };

    unlink $stats19->db_file;

    my $db = $stats19->db;

    $db->deploy;

    for my $rs_name (qw/
        AccidentSeverity
        AgeBand
        BusPassenger
        CarPassenger
        CarriagewayHazards
        CasualtyClass
        CasualtySeverity
        CasualtyType
        DayOfWeek
        Highways
        HitObjectInCarriageway
        HitObjectOffCarriageway
        HomeAreaType
        ImdDecile
        JourneyPurpose
        JunctionControl
        JunctionDetail
        JunctionLocation
        LightConditions
        LocalAuthorityDistrict
        LocalAuthorityHighway
        PedCrossHuman
        PedCrossPhysical
        PedestrianLocation
        PedestrianMovement
        PedestrianRoadMaintenanceWorker
        PointOfImpact1
        PoliceForce
        PoliceOfficerAttend
        RoadClass
        RoadSurface
        RoadType
        SexOfCasualty
        SexOfDriver
        SkiddingAndOverturning
        SpecialConditionsAtSite
        TowingAndArticulation
        UrbanRural
        VehicleLeavingCarriageway
        VehicleLocation
        VehicleManouvre
        VehiclePropulsionCode
        VehicleType
        WasVehicleLeftHandDrive
        WeatherConditions

        Accident
        Vehicle
        Casualty
    /) {
        $self->populate_table( $stats19, $rs_name );
    }
}

my %map = (
    # from Accidents
    'Local_Authority_(District)' => 'local_authority_district_code',
    'Local_Authority_(Highway)' => 'local_authority_highway_code',
    'Pedestrian_Crossing-Human_Control' => 'pedestrian_crossing_human_control_code',
    'Pedestrian_Crossing-Physical_Facilities' => 'pedestrian_crossing_physical_facilities_code',
    '1st_Road_Class' => 'road_1_class_code',
    '2nd_Road_Class' => 'road_2_class_code',
    '1st_Road_Number' => 'road_1_number',
    '2nd_Road_Number' => 'road_2_number',

    # from Vehicles
    'Acc_Index' => 'accident_index', # normalize
    '1st_Point_of_Impact' => 'point_of_impact_1_code',
    'Was_Vehicle_Left_Hand_Drive?' => 'was_vehicle_left_hand_drive_code',
    'Engine_Capacity_(CC)' => 'engine_capacity_cc',
    'Vehicle_Location-Restricted_Lane' => 'vehicle_location_restricted_lane_code',
);

sub _table_name {
    my $rs_name = shift;
    my $map = {
        Accident => 'accidents',
        Casualty => 'casualties',
        Vehicle  => 'vehicles',
    };
    return $map->{$rs_name} || 
        # decamelize
        lc join '_' => $rs_name =~ /([A-Z0-9][a-z]*)/g;
}

sub populate_table {
    my ($self, $stats19, $rs_name) = @_;

    my $file = _table_name( $rs_name );
    say "$rs_name => $file";

    my $csv = $self->csv;
    open my $fh, '<:via(File::BOM)', path( $stats19->data_directory, "$file.csv" )->stringify
        or die "$file.csv: $!";

    my $rs = $stats19->db->resultset($rs_name);

    my $resolve_title = do {
        my $source = $rs->result_source;
        sub {
            my $name = shift;
            $map{$name} || do {
                $name = lc $name;
                my $name_code = "${name}_code";
                $source->has_column($name_code) ? $name_code : $name;
            };
        };
    };

    my @header = map { $resolve_title->($_) } @{ $csv->getline ($fh) };

    $| = 1;

    $stats19->db->txn_do( sub {
        eval {
            while (my $row = $csv->getline($fh) ) {
                # print $row->[0];
                my %hash = zip @header, @$row;

                if (exists $hash{date}) {
                    my $date = (exists $hash{time}) ?
                        DateTime::Format::Strptime->new(pattern => '%d/%m/%Y %H:%M')
                            ->parse_datetime( join ' ', @hash{'date', 'time'} ) 
                        :
                        DateTime::Format::Strptime->new(pattern => '%d/%m/%Y')
                            ->parse_datetime( $hash{date} );
                    $hash{date} = $date;
                }
                $rs->create( \%hash );
                print '.';
            }
        };
        if ($@) {
            warn join ',', $rs->result_source->columns;
            die $@ unless $@ =~ /Bizarre copy/; # known error in dev due to encoding of edited csv
        }
    });
    say '';
}

1;
