package FixMyStreet::App::Form::Waste::Garden::Bexley;

use utf8;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Waste::Garden';

with 'FixMyStreet::App::Form::Waste::AccessPaySuiteBankDetails';

# Create a dedicated page for entering bank details.
has_page bank_details => (
    title => 'Enter Your Bank Details',
    template => 'waste/bank_details.html',
    fields => ['name_title', 'first_name', 'surname', 'address1', 'address2', 'address3', 'address4', 'post_code', 'account_holder', 'account_number', 'sort_code', 'submit_bank_details'],
    next => 'summary',
);

1;
