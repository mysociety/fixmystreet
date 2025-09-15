package FixMyStreet::App::Form::Waste::Garden::Renew::Bexley;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Renew';

with 'FixMyStreet::App::Form::Waste::AccessPaySuiteBankDetails';
with 'FixMyStreet::App::Form::Waste::Garden::Verify::Bexley';

has_page customer_reference =>
    ( customer_reference( continue_field => 'continue_choice' ) );

has_page about_you =>
    ( about_you( continue_field => 'continue_choice', next_page => 'intro' ) );

has_page intro => remove_about_you_fields(
    FixMyStreet::App::Form::Waste::Garden::Renew::intro() );

has_page bank_details => ( bank_details() );

1;
