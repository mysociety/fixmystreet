package FixMyStreet::Cobrand::Harrogate;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2407; }
sub council_area { return 'Harrogate'; }
sub council_name { return 'Harrogate Borough Council'; }
sub council_url { return 'harrogate'; }
sub is_two_tier { return 1; } # with North Yorkshire CC 2235

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Harrogate';

    # as it's the requested example location, try to avoid a disambiguation page
    $town .= ', HG1 1DH' if $string =~ /^\s*king'?s\s+r(?:oa)?d\s*(?:,\s*har\w+\s*)?$/i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '54.0671557690306,-1.59581319536637',
        span   => '0.370193897090822,0.829517054931808',
        bounds => [ 53.8914112467619, -2.00450542308575, 54.2616051438527, -1.17498836815394 ],
    };
}

sub example_places {
    return ( 'HG1 2SG', "King's Road" );
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a Harrogate postcode, or street name and area';
}

# increase map zoom level so street names are visible
sub default_map_zoom { return 3; }


=head2 temp_email_to_update, temp_update_contacts

Temporary helper routines to update the extra for potholes (temporary setup
hack, cargo-culted from ESCC, may in future be superseded either by
Open311/integration or a better mechanism for manually creating rich contacts).

Can run with a script or command line like:

 bin/cron-wrapper perl -MFixMyStreet::App -MFixMyStreet::Cobrand::Harrogate -e \
 'FixMyStreet::Cobrand::Harrogate->new({c => FixMyStreet::App->new})->temp_update_contacts'

=cut

sub temp_update_contacts {
    my $self = shift;

    my $category = 'Potholes';
    my $contact = $self->{c}->model('DB::Contact')
        ->search({
            body_id => $self->council_id,
            category => $category,
        })->first
        or die "No such category: $category";

    my $fields = [
        {
            'code' => 'detail_size', # there is already builtin handling for this field in Report::New
            'variable' => 'true',
            'order' => '1',
            'description' => 'Size of the pothole?',
            'required' => 'true',
            'datatype' => 'singlevaluelist',
            'datatype_description' => {}, 
            'values' => {
                'value' => $self->POTHOLE_SIZES,
            },
        }
    ];
    # require IO::String; require RABX;
    # RABX::wire_wr( $fields, IO::String->new(my $extra) );

    $contact->update({ extra => $fields });
}

1;

