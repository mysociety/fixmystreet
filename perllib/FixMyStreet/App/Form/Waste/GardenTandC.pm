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
            $text = 'I agree to the <a href="/about/garden_terms" target="_blank">terms and conditions</a> and accept that if my bin does not display a valid bin sticker, it will not be collected';
        } else {
            $text = 'I agree to the <a href="/about/garden_terms" target="_blank">terms and conditions</a>';
        }
        return FixMyStreet::Template::SafeString->new($text);
    },
);

1;
