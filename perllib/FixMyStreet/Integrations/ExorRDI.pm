package FixMyStreet::Integrations::ExorRDI::Error;

use Moo;
with 'Throwable';

has message => (is => 'ro');

package FixMyStreet::Integrations::ExorRDI;

use DateTime;
use Moo;
use Scalar::Util 'blessed';
use Text::CSV;
use FixMyStreet::DB;
use namespace::clean;

has [qw(start_date end_date)] => (
    is => 'ro',
    required => 1,
);

has user => (
    is => 'ro',
    coerce => sub {
        return $_[0] if blessed($_[0]) && $_[0]->isa('FixMyStreet::DB::Result::User');
        FixMyStreet::DB->resultset('User')->find( { id => $_[0] } )
            if $_[0];
    },
);

sub construct {
    my $self = shift;

    my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('oxfordshire')->new;
    my $dtf = $cobrand->problems->result_source->storage->datetime_parser;

    my %params = (
        -and => [
            state => [ 'action scheduled' ],
            external_id => { '!=' => undef },
            'admin_log_entries.action' => 'inspected',
            'admin_log_entries.whenedited' => { '>=', $dtf->format_datetime($self->start_date) },
            'admin_log_entries.whenedited' => { '<=', $dtf->format_datetime($self->end_date) },
        ]
    );

    $params{'admin_log_entries.user_id'} = $self->user->id if $self->user;

    my $problems = $cobrand->problems->search(
        \%params,
        {
            join => 'admin_log_entries',
            distinct => 1,
        }
    );
    FixMyStreet::Integrations::ExorRDI::Error->throw unless $problems->count;

    # A single RDI file might contain inspections from multiple inspectors, so
    # we need to group inspections by inspector within G records.
    my $inspectors = {};
    my $inspector_initials = {};
    while ( my $report = $problems->next ) {
        my $user = $report->inspection_log_entry->user;
        $inspectors->{$user->id} ||= [];
        push @{ $inspectors->{$user->id} }, $report;
        unless ( $inspector_initials->{$user->id} ) {
            $inspector_initials->{$user->id} = $user->get_extra_metadata('initials');
        }
    }

    my $csv = Text::CSV->new({ binary => 1, eol => "" });

    my $p_count = 0;
    my $link_id = $cobrand->exor_rdi_link_id;

    # RDI first line is always the same
    $csv->combine("1", "1.8", "1.0.0.0", "ENHN", "");
    my @body = ($csv->string);

    my $i = 0;
    foreach my $inspector_id (keys %$inspectors) {
        my $inspections = $inspectors->{$inspector_id};
        my $initials = $inspector_initials->{$inspector_id};

        $csv->combine(
            "G", # start of an area/sequence
            $link_id, # area/link id, fixed value for our purposes
            "","", # must be empty
            $initials || "XX", # inspector initials
            $self->start_date->strftime("%y%m%d"), # date of inspection yymmdd
            "0700", # time of inspection hhmm, set to static value for now
            "D", # inspection variant, should always be D
            "INS", # inspection type, always INS
            "N", # Area of the county - north (N) or south (S)
            "", "", "", "" # empty fields
        );
        push @body, $csv->string;

        $csv->combine(
            "H", # initial inspection type
            "MC" # minor carriageway (changes depending on activity code)
        );
        push @body, $csv->string;

        foreach my $report (@$inspections) {
            my ($eastings, $northings) = $report->local_coords;

            my $location = "${eastings}E ${northings}N";
            $location = "[DID NOT USE MAP] $location" unless $report->used_map;
            my $closest_address = $cobrand->find_closest($report, 1);
            if (%$closest_address) {
                $location .= " Nearest road: $closest_address->{road}." if $closest_address->{road};
                $location .= " Nearest postcode: $closest_address->{postcode}{postcode}." if $closest_address->{postcode};
            }

            my $description = sprintf("%s %s", $report->external_id || "", $report->get_extra_metadata('detailed_information') || "");
            my $activity_code = $report->defect_type ?
                $report->defect_type->get_extra_metadata('activity_code')
                : 'MC';
            my $traffic_information = $report->get_extra_metadata('traffic_information') ?
                'TM ' . $report->get_extra_metadata('traffic_information')
                : 'TM none';

            $csv->combine(
                "I", # beginning of defect record
                $activity_code, # activity code - minor carriageway, also FC (footway)
                "", # empty field, can also be A (seen on MC) or B (seen on FC)
                sprintf("%03d", ++$i), # randomised sequence number
                $location, # defect location field, which we don't capture from inspectors
                $report->inspection_log_entry->whenedited->strftime("%H%M"), # defect time raised
                "","","","","","","", # empty fields
                $traffic_information,
                $description, # defect description
            );
            push @body, $csv->string;

            my $defect_type = $report->defect_type ?
                              $report->defect_type->get_extra_metadata('defect_code')
                              : 'SFP2';
            $csv->combine(
                "J", # georeferencing record
                $defect_type, # defect type - SFP2: sweep and fill <1m2, POT2 also seen
                $report->response_priority ?
                    $report->response_priority->external_id :
                    "2", # priority of defect
                "","", # empty fields
                $eastings, # eastings
                $northings, # northings
                "","","","","" # empty fields
            );
            push @body, $csv->string;

            $csv->combine(
                "M", # bill of quantities record
                "resolve", # permanent repair
                "","", # empty fields
                "/CMC", # /C + activity code
                "", "" # empty fields
            );
            push @body, $csv->string;
        }

        # end this group of defects with a P record
        $csv->combine(
            "P", # end of area/sequence
            0, # always 0
            999999, # charging code, always 999999 in OCC
        );
        push @body, $csv->string;
        $p_count++;
    }

    # end the RDI file with an X record
    my $record_count = $i;
    $csv->combine(
        "X", # end of inspection record
        $p_count,
        $p_count,
        $record_count, # number of I records
        $record_count, # number of J records
        0, 0, 0, # always zero
        $record_count, # number of M records
        0, # always zero
        $p_count,
        0, 0, 0 # error counts, always zero
    );
    push @body, $csv->string;

    # The RDI format is very weird CSV - each line must be wrapped in
    # double quotes.
    return join "", map { "\"$_\"\r\n" } @body;
}

has filename => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $start = $self->start_date->strftime("%Y%m%d");
        my $end = $self->end_date->strftime("%Y%m%d");
        my $filename = sprintf("exor_defects-%s-%s.rdi", $start, $end);
        if ( $self->user ) {
            my $initials = $self->user->get_extra_metadata("initials") || "";
            $filename = sprintf("exor_defects-%s-%s-%s.rdi", $start, $end, $initials);
        }
        return $filename;
    },
);

1;
