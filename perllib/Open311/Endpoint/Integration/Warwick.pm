package Open311::Endpoint::Integration::Warwick;
use Web::Simple;
extends 'Open311::Endpoint::Integration::Exor';

sub services {
    # TODO, get this from ::Exor
    my @services = (
        [ BR => 'Bridges' ],
        [ CD => 'Carriageway Defect' ],
        [ CD => 'Roads/Highways' ],
        [ DR => 'Drainage' ],
        [ DS => 'Debris/Spillage' ],
        [ FE => 'Fences' ],
        [ 'F D' => 'Pavements' ],
        [ GC => 'Gully & Catchpits' ],
        [ IS => 'Ice/Snow' ],
        [ MD => 'Mud & Debris' ],
        [ MH => 'Manhole' ],
        [ OS => 'Oil Spillage' ],
        [ OT => 'Other' ],
        [ PO => 'Pothole' ],
        [ PD => 'Property Damage' ],
        [ RM => 'Road Marking' ],
        [ SN => 'Road traffic signs' ],
        [ SP => 'Traffic' ],
        [ UT => 'Utilities' ],
        [ VG => 'Vegetation' ],
    );
    return map {
        my ($code, $name) = @$_;
        Open311::Endpoint::Service->new(
            service_code => $code,
            service_name => $name,
            description => $name,
            type => 'realtime',
            keywords => [qw/ /],
            group => 'highways',
        ),
    } @services;
}

1;
