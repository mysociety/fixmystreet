package FixMyStreet::App::Form::Waste::Garden::Renew::Bexley;

use utf8;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden::Renew';

with 'FixMyStreet::App::Form::Waste::AccessPaySuiteBankDetails';

has_page bank_details => ( bank_details() );

1;
