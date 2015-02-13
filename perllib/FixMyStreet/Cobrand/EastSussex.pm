package FixMyStreet::Cobrand::EastSussex;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2224; }
sub council_area { return 'East Sussex'; }
sub council_name { return 'East Sussex County Council'; }
sub council_url { return 'eastsussex'; }
sub is_two_tier { return 1; }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'East Sussex',
        centre => '50.9413275309703,0.276320277101682',
        span   => '0.414030932264716,1.00374244745585',
        bounds => [ 50.7333642759327, -0.135851370247794, 51.1473952081975, 0.867891077208056 ],
    };
}

sub example_places {
    return ( 'BN7 2LZ', 'White Hill, Lewes' );
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter an East Sussex postcode, or street name and area';
}

# increase map zoom level so street names are visible
sub default_map_zoom { return 3; }


=head2 temp_update_potholes_contact

Routine to update the extra for potholes (temporary setup hack, will be
superseded by Open311/integration).

Can run with a script or command line like:

 bin/cron-wrapper perl -MFixMyStreet::App -MFixMyStreet::Cobrand::EastSussex -e \
 'FixMyStreet::Cobrand::EastSussex->new({c => FixMyStreet::App->new})->temp_update_potholes_contact'

=cut

use constant POTHOLE_SIZES => [
    {'key' => ['Blank'],    'name' => ['--']}, 
    {'key' => ['golf'],     'name' => ['Golf ball sized']}, 
    {'key' => ['tennis'],   'name' => ['Tennis ball sized']}, 
    {'key' => ['football'], 'name' => ['Football sized']},
    {'key' => ['larger'],   'name' => ['Larger']}
];

use constant POTHOLE_DICT => {
    map {
        @{ $_->{key} }, 
        @{ $_->{name} },
    } @{ POTHOLE_SIZES() },
};

sub resolve_pothole_size {
    my ($self, $key) = @_;
    return $self->POTHOLE_DICT->{$key};
}

sub temp_update_potholes_contact {
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

sub get_geocoder {
    return 'OSM'; # default of Bing gives poor results, let's try overriding.
}

# for the /around/ page
sub on_map_default_max_pin_age {
    return '3 months';
}

# for the /reports/ page
sub reports_per_page { return 20; }

sub pin_colour {
    my ( $self, $p, $context ) = @_;

    # TODO refactor to a Moo(se)? lazy attribute
    my $open_states = $self->{open_states} ||= $p->open_states;

    return $open_states->{ $p->state } ? 'yellow' : 'green';
}

sub send_questionnaires {
    return 0;
}

1;

