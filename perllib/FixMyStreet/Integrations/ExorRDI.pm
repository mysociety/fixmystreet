package FixMyStreet::Integrations::ExorRDI::Error;

use Moo;
with 'Throwable';

has message => (is => 'ro');

package FixMyStreet::Integrations::ExorRDI::CSV;

use parent 'Text::CSV';

sub add_row {
    my ($self, $data, @data) = @_;
    $self->combine(@data);
    push @$data, $self->string;
}

package FixMyStreet::Integrations::ExorRDI;

use DateTime;
use Moo;
use Scalar::Util 'blessed';
use FixMyStreet::DB;
use namespace::clean;

has [qw(start_date end_date inspection_date mark_as_processed)] => (
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
    my $now = DateTime->now(
        time_zone => FixMyStreet->time_zone || FixMyStreet->local_time_zone
    );

    my $tmo = $cobrand->traffic_management_options;
    my %tm_lookup = map { $tmo->[$_] => $_ + 1 } 0..$#$tmo;

    my $missed_cutoff = $now - DateTime::Duration->new( hours => 24 );
    my %params = (
        -and => [
            state => [ 'action scheduled' ],
            external_id => { '!=' => undef },
            -or => [
                -and => [
                    'admin_log_entries.action' => 'inspected',
                    'admin_log_entries.whenedited' => { '>=', $dtf->format_datetime($self->start_date) },
                    'admin_log_entries.whenedited' => { '<=', $dtf->format_datetime($self->end_date) },
                ],
                -and => [
                    extra => { -not_like => '%rdi_processed%' },
                    'admin_log_entries.action' => 'inspected',
                    'admin_log_entries.whenedited' => { '<=', $dtf->format_datetime($missed_cutoff) },
                ]
            ]
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

    my $csv = FixMyStreet::Integrations::ExorRDI::CSV->new({ binary => 1, eol => "" });

    my $p_count = 0;
    my $link_id = $cobrand->exor_rdi_link_id;

    # RDI first line is always the same
    my $body = [];
    $csv->add_row($body, "1", "1.8", "1.0.0.0", "ENHN", "");

    my $i = 0;
    foreach my $inspector_id (keys %$inspectors) {
        my $inspections = $inspectors->{$inspector_id};
        my $initials = $inspector_initials->{$inspector_id} || "XX";

        my %body_by_activity_code;
        foreach my $report (@$inspections) {
            my ($eastings, $northings) = $report->local_coords;

            my $location = "${eastings}E ${northings}N";
            $location = "[DID NOT USE MAP] $location" unless $report->used_map;
            my $closest_address = $cobrand->find_closest($report, 1);
            if (%$closest_address) {
                $location .= " Nearest road: $closest_address->{road}." if $closest_address->{road};
                $location .= " Nearest postcode: $closest_address->{postcode}{postcode}." if $closest_address->{postcode};
            }

            my $traffic_information = $report->get_extra_metadata('traffic_information') || 'none';
            my $description = sprintf("%s %s %s %s",
                $report->external_id || "",
                $initials,
                'TM' . ($tm_lookup{$traffic_information} || '0'),
                $report->get_extra_metadata('detailed_information') || "");
            # Maximum length of 180 characters total
            $description = substr($description, 0, 180);
            my $activity_code = $report->defect_type ?
                $report->defect_type->get_extra_metadata('activity_code')
                : 'MC';
            $body_by_activity_code{$activity_code} ||= [];

            $csv->add_row($body_by_activity_code{$activity_code},
                "I", # beginning of defect record
                $activity_code, # activity code - minor carriageway, also FC (footway)
                "", # empty field, can also be A (seen on MC) or B (seen on FC)
                sprintf("%03d", ++$i), # randomised sequence number
                $location, # defect location field, which we don't capture from inspectors
                $report->inspection_log_entry->whenedited->strftime("%H%M"), # defect time raised
                "","","","","","","", # empty fields
                "TM $traffic_information",
                $description, # defect description
            );

            my $defect_type = $report->defect_type ?
                              $report->defect_type->get_extra_metadata('defect_code')
                              : 'SFP2';
            $csv->add_row($body_by_activity_code{$activity_code},
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

            my $m_row_activity_code = $activity_code;
            $m_row_activity_code .= 'I' if length $activity_code == 1;

            $csv->add_row($body_by_activity_code{$activity_code},
                "M", # bill of quantities record
                "resolve", # permanent repair
                "","", # empty fields
                "/C$m_row_activity_code", # /C + activity code + perhaps an "I"
                "", "" # empty fields
            );
        }

        foreach my $activity_code (sort keys %body_by_activity_code) {
            $csv->add_row($body,
                "G", # start of an area/sequence
                $link_id, # area/link id, fixed value for our purposes
                "","", # must be empty
                $initials, # inspector initials
                $self->inspection_date->strftime("%y%m%d"), # date of inspection yymmdd
                "1600", # time of inspection hhmm, set to static value for now
                "D", # inspection variant, should always be D
                "INS", # inspection type, always INS
                "N", # Area of the county - north (N) or south (S)
                "", "", "", "" # empty fields
            );

            $csv->add_row($body,
                "H", # initial inspection type
                $activity_code # e.g. MC = minor carriageway
            );

            # List of I/J/M entries from above
            push @$body, @{$body_by_activity_code{$activity_code}};

            # end this group of defects with a P record
            $csv->add_row($body,
                "P", # end of area/sequence
                0, # always 0
                999999, # charging code, always 999999 in OCC
            );
            $p_count++;
        }
    }

    # end the RDI file with an X record
    my $record_count = $i;
    $csv->add_row($body,
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

    if ($self->mark_as_processed) {
        # Mark all these problems are having been included in an RDI
        $problems->reset;
        while ( my $report = $problems->next ) {
            $report->set_extra_metadata('rdi_processed' => $now->strftime( '%Y-%m-%d %H:%M' ));
            $report->update;
        }
    }

    # The RDI format is very weird CSV - each line must be wrapped in
    # double quotes.
    return join "", map { "\"$_\"\r\n" } @$body;
}

has filename => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $start = $self->inspection_date->strftime("%Y%m%d");
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
