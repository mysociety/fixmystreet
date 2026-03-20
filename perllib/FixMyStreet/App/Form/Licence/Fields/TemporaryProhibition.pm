package FixMyStreet::App::Form::Licence::Fields::TemporaryProhibition;

use utf8;
use HTML::FormHandler::Moose::Role;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::TemporaryProhibition - Temporary prohibition fields for licence forms

=head1 DESCRIPTION

Provides temporary traffic prohibition fields used by all TfL licence forms:
parking_dispensation, parking_bay_suspension, bus_stop_suspension,
bus_lane_suspension, road_closure_required, terms_accepted

These fields are identical across all 16 licence types.

=cut

has_field parking_dispensation => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a parking dispensation be required?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
    tags => { hint => FixMyStreet::Template::SafeString->new('Please consider <a href="https://tfl.gov.uk/modes/driving/red-routes/dispensations" target="_blank" rel="noopener">TfL Red Route dispensations</a>') },
);

has_field bus_stop_suspension => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a temporary bus stop suspension be required?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
    tags => { hint => FixMyStreet::Template::SafeString->new('Please read about <a href="https://tfl.gov.uk/info-for/urban-planning-and-construction/our-land-and-infrastructure/roadworks-and-street-faults#on-this-page-10" target="_blank" rel="noopener">Bus stop suspensions</a>') },
);

has_field bus_lane_suspension => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a bus lane need to be suspended?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
    tags => { hint => 'If yes, a TCSR will be required' },
);

has_field parking_bay_suspension => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a parking, loading, disabled or motorcycle parking bay need to be suspended?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
    tags => { hint => 'If yes, a TCSR will be required, or a possible TTRO' },
);

has_field road_closure_required => (
    type => 'Select',
    widget => 'RadioGroup',
    label => 'Will a road closure be required?',
    required => 1,
    options => [
        { label => 'Yes', value => 'Yes' },
        { label => 'No', value => 'No' },
    ],
    tags => { hint => 'If yes, a TTRO will be required' },
);

has_field tcsr_website_note => (
    type  => 'Notice',
    label => '<p>Please refer to our <a href="https://tfl.gov.uk/info-for/urban-planning-and-construction/our-land-and-infrastructure/highway-licences#on-this-page-3" target="_blank" rel="noopener">website</a> on how to apply for a TCSR or TTRO.</p>',
    required => 0,
    widget   => 'NoRender',
);

has_field terms_accepted => (
    type => 'Multiple',
    widget => 'CheckboxGroup',
    label => 'I confirm that I have read and agree to comply with all requirements set out within the following documents',
    required => 1,
    validate_method => sub {
        my $self = shift;
        my $vals = $self->value;
        $self->add_error('Please confirm all options') if @$vals < 3;
    },
);

sub options_terms_accepted {
    my $name = $_[0]->name;
    my $tandc_link = $_[0]->tandc_link;
    my @options;
    push @options,
        { label => "<a target='_blank' href='$tandc_link'>$name guidance notes and terms &amp; conditions - March 2026</a>", value => "$name guidance notes and terms & conditions - March 2026" },
        { label => '<a target="_blank" href="https://content.tfl.gov.uk/highway-licensing-and-other-consents-policy.pdf">TfL’s Highways Licensing and Other Consents Policy - March 2026</a>', value => 'Highway licensing and other consents policy - March 2026' },
        { label => '<a target="_blank" href="https://content.tfl.gov.uk/standard-conditions-for-highway-consents.pdf">TfL’s Standard Conditions for Highway Consents - March 2026</a>', value => 'Standard conditions for highway consents - March 2026' };
    foreach (@options) {
        $_->{label} = FixMyStreet::Template::SafeString->new($_->{label});
    }
    return @options;
}

1;
