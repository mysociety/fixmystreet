package Dataset::UK::Stats19::Cmd::Deploy;
use Moo;
use MooX::Cmd;
use Path::Tiny;
use Text::CSV_XS;
use File::BOM;
use List::MoreUtils 'zip';
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

    $self->populate_table( $stats19, 'Accident' );

    # my $result = $db->resultset('Accident')->first;
    # say Dumper({ $result->get_columns }); use Data::Dumper;
    # say $db->resultset('Accident')->count;
}

my %map = (
    'Local_Authority_(District)' => 'local_authority_district',
    'Local_Authority_(Highway)' => 'local_authority_highway',
    'Pedestrian_Crossing-Human_Control' => 'pedestrian_crossing_human_control',
    'Pedestrian_Crossing-Physical_Facilities' => 'pedestrian_crossing_physical_facilities',
    '1st_Road_Class' => 'road_1_class',
    '2nd_Road_Class' => 'road_2_class',
    '1st_Road_Number' => 'road_1_number',
    '2nd_Road_Number' => 'road_2_number',
);

sub populate_table {
    my ($self, $stats19, $table) = @_;

    my $file = {
        Accident => 'accidents',
        Casualty => 'casualties',
        Vehicle  => 'vehicles',
    }->{$table} or die "No table for $table";

    my $csv = $self->csv;
    open my $fh, '<:via(File::BOM)', path( $stats19->data_directory, "$file.csv" )->stringify
        or die "$file.csv: $!";

    my @header = map {
        $map{$_} || lc
    } @{ $csv->getline ($fh) };

    my $rs = $stats19->db->resultset($table);

    $| = 1;

    $stats19->db->txn_do( sub {
        while (my $row = $csv->getline($fh) ) {
            my %hash = zip @header, @$row;
            $rs->create( \%hash );
            print '.';
        }
    });
}

1;
