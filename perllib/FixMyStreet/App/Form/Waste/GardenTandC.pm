package FixMyStreet::App::Form::Waste::GardenTandC;

use utf8;
use HTML::FormHandler::Moose::Role;

has_field tandc => (
    type => 'Checkbox',
    required => 1,
    label => 'Terms and conditions',
    build_option_label_method => sub {
        my $cobrand = $_[0]->form->{c}->cobrand;
        my $text;
        if ($cobrand->moniker eq 'brent') {
            $text = 'I agree to the <a href="/about/garden_terms" target="_blank">terms and conditions</a> and accept that if my bin does not display a valid bin sticker, it will not be collected. I acknowledge that it can take up to 10 days from signing up for my bin sticker to arrive.';
        } elsif ($cobrand->moniker eq 'bexley') {
            $text = 'I agree to the <a href="https://www.bexley.gov.uk/services/rubbish-and-recycling/garden-waste-collection-service/sign-garden-waste-collection" target="_blank">terms and conditions</a>';
        } else {
            $text = 'I agree to the <a href="/about/garden_terms" target="_blank">terms and conditions</a>';
        }
        return FixMyStreet::Template::SafeString->new($text);
    },
);

1;
