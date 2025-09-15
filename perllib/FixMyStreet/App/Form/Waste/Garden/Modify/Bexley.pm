package FixMyStreet::App::Form::Waste::Garden::Modify::Bexley;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Modify';

has_page about_you => (
    fields => ['name', 'phone', 'email', 'continue'],
    title => 'About you',
    next => 'alter',
);

sub alter_override {
    my %defaults = FixMyStreet::App::Form::Waste::Garden::Modify::alter();
    my @fields = grep { $_ !~ /^(name|phone|email)$/ } @{ $defaults{fields} };
    $defaults{fields} = \@fields;
    return %defaults;
}

has_page alter => ( alter_override() );

1;
