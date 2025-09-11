package FixMyStreet::App::Form::Waste::Garden::Renew::Bexley;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Renew';

with 'FixMyStreet::App::Form::Waste::AccessPaySuiteBankDetails';

has_page about_you => (
    fields => ['name', 'phone', 'email', 'continue_choice'],
    title => 'About you',
    next => 'intro',
);

sub intro_override {
    my %defaults = FixMyStreet::App::Form::Waste::Garden::Renew::intro();
    my @fields = grep { $_ !~ /^(name|phone|email)$/ } @{ $defaults{fields} };
    $defaults{fields} = \@fields;
    return %defaults;
}

has_page intro => ( intro_override() );

has_page bank_details => ( bank_details() );

1;
