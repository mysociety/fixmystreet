package FixMyStreet::Script::TfL::BusImport;

use v5.14;

use Moo;
use CronFns;
use Term::ANSIColor;
use Path::Tiny;
use Text::CSV;
use FixMyStreet;
use FixMyStreet::Cobrand;
use FixMyStreet::DB;
use Types::Standard qw(InstanceOf Maybe);
use Utils;


has verbose => ( is => 'ro', default => 0 );

has file => ( is => 'ro' );

has body => (
    is => 'lazy',
    isa => Maybe[InstanceOf['FixMyStreet::DB::Result::Body']],
    default => sub {
        FixMyStreet::DB->resultset('Body')->find({ name => 'TfL' });
    }
);

has cobrand => (
    is => 'lazy',
    default => sub {
        shift->body->get_cobrand_handler;
    }
);

sub process {
    my $self = shift;

    die "TfL body does not exist\n" unless $self->body;
    die "CSV file does not exist\n" unless -f $self->file;

    # Parse CSV file
    my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
    open my $fh, '<:encoding(utf8)', $self->file or die "Can't open file: $!";

    # Read header row
    my @headers = $csv->header($fh);

    # Validate required fields exist (NB converted to lowercase by above line)
    my @required_fields = ('title', 'description', 'category', 'building name', 'building id', 'sub-category');

    my %headers = map { $_ => 1 } @headers;

    for my $field (@required_fields) {
        die "Missing required field '$field' in CSV header\n" unless $headers{$field};
    }

    # Get available categories for validation
    my %valid_categories = map { $_->category => 1 } $self->body->contacts->all;

    my $comment_user = $self->body->comment_user;
    die "TfL body has no comment user configured\n" unless $comment_user;

    my $reports_created = 0;
    my $reports_failed = 0;

    # Process each row
    while (my $row = $csv->getline_hr($fh)) {
        eval {
            my $title = Utils::trim_text($row->{title});
            my $description = Utils::trim_text($row->{description});
            my $category = Utils::trim_text($row->{category});
            my $building_name = Utils::trim_text($row->{'building name'});
            my $building_id = Utils::trim_text($row->{'building id'});
            my $sub_category = Utils::trim_text($row->{'sub-category'});

            # Skip empty rows
            next unless $title && $description && $building_id && $sub_category;

            # Validate category exists
            unless ($valid_categories{$sub_category}) {
                die "Category '$sub_category' does not exist for TfL body";
            }

            # Get location if Building ID provided
            my ($latitude, $longitude) = $self->find_location($building_id);
            unless ($latitude && $longitude) {
                die "Could not find location for Building ID '$building_id'";
            }

            my ($lat, $lon) = map { Utils::truncate_coordinate($_) } $latitude, $longitude;
            my $areas = FixMyStreet::MapIt::call('point', "4326/" . $lon . "," . $lat);

            # Create report
            my $report = FixMyStreet::DB->resultset('Problem')->create({
                title => $title,
                detail => $description,
                category => $sub_category,
                latitude => $latitude,
                longitude => $longitude,
                user_id => $comment_user->id,
                name => $comment_user->name || 'TfL Import',
                anonymous => 0,
                state => 'confirmed',
                confirmed => \'current_timestamp',
                created => \'current_timestamp',
                whensent => \'current_timestamp',
                lang => 'en-gb',
                service => '',
                cobrand => 'tfl',
                cobrand_data => '',
                send_questionnaire => 0,
                bodies_str => $self->body->id,
                areas => ',' . join( ',', sort keys %$areas ) . ',',
                used_map => 1,
                non_public => 1,
                postcode => '',
                send_state => 'processed',
                $category ? (extra => { group => $category }) : (),
            });
            $report->update_extra_field({ name => 'SITE_NAME', value => $building_name }) if $building_name;
            $report->update_extra_field({ name => 'SITE_ID', value => $building_id }) if $building_id;
            $report->update;

            if ($self->verbose) {
                say "Created report ID " . $report->id . " for '$title'";
            }

            $reports_created++;
        };

        if ($@) {
            warn "Failed to process row: $@";
            $reports_failed++;
        }
    }

    close $fh;

    say colored("Reports created: $reports_created", 'green');
    say colored("Reports failed: $reports_failed", 'red') if $reports_failed;
}

sub find_location {
    my ($self, $id) = @_;

    return unless $id;

    my $filter = "<ogc:Filter xmlns:ogc=\"http://www.opengis.net/ogc\">
        <ogc:PropertyIsEqualTo>
            <ogc:PropertyName>SITE_ID</ogc:PropertyName>
            <ogc:Literal>$id</ogc:Literal>
        </ogc:PropertyIsEqualTo>
    </ogc:Filter>";
    $filter =~ s/\n\s+//g;

    my $cfg = {
        url => FixMyStreet->config('STAGING_SITE')
            ? "https://tilma.staging.mysociety.org/mapserver/tfl"
            : "https://tilma.mysociety.org/mapserver/tfl",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => 'buspremisesites',
        filter => $filter,
    };

    my $features = $self->cobrand->_fetch_features($cfg);
    return unless $features && @$features;

    # Get the first matching feature
    my $feature = $features->[0];
    my $geometry = $feature->{geometry};

    my ($e, $n) = @{$geometry->{coordinates}};
    my ($latitude, $longitude) = Utils::convert_en_to_latlon($e, $n);

    if ($self->verbose && $latitude && $longitude) {
        say "Found location for Building ID $id: $latitude, $longitude";
    }

    return ($latitude, $longitude);
}

1;
