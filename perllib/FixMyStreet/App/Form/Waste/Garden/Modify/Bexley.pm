package FixMyStreet::App::Form::Waste::Garden::Modify::Bexley;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Modify';

with 'FixMyStreet::App::Form::Waste::Garden::AboutYou::Bexley';

has_page about_you =>
    ( about_you( continue_field => 'continue', next_page => 'alter' ) );

has_page alter => remove_about_you_fields(
    FixMyStreet::App::Form::Waste::Garden::Modify::alter() );

1;
