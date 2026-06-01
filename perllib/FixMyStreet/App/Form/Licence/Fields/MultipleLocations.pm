package FixMyStreet::App::Form::Licence::Fields::MultipleLocations;

use utf8;
use HTML::FormHandler::Moose::Role;
use MooseX::Role::Parameterized;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::MultipleLocations - Further location pages for licence forms

=head1 DESCRIPTION

Provides further pages of location fields for TfL licence forms.

=cut

parameter pages => ( isa => 'Int' );
parameter title => ( isa => 'Str' );
parameter template => ( isa => 'Str' );

role {
    my $p = shift;
    my $pages = $p->pages;
    my $title = $p->title;
    my $template = $p->template;

    for my $page (2..$pages) {
        my $next = 'dates';
        my $fields = ["building_name_number_$page", "street_name_$page", "borough_$page", "postcode_$page", 'continue'];
        if ($page < $pages) {
            $next = sub { $_[1]->{add_another} ? 'location_' . ($page+1) : 'dates' };
            push @$fields, 'add_another';
        }

        # has_page doesn't work in a role
        __PACKAGE__->meta->add_to_page_list( {
            name => "location_$page",
            step_number => 1,
            fields => $fields,
            update_field_list => sub {
                my $data = $_[0]->saved_data;
                return {
                    "street_name_$page" => { default => $data->{street_name} },
                    "borough_$page" => { default => $data->{borough} },
                }
            },
            title => "$title ($page)",
            intro => $template,
            next => $next,
            tags => { hide => sub { !$_[0]->form->saved_data->{"building_name_number_$page"} } },
        } );
        has_field "building_name_number_$page" => ( type => 'Text', label => 'Building name / number', required => 1 );
        has_field "street_name_$page" => ( type => 'Text', label => 'Street name', disabled => 1 );
        has_field "borough_$page" => ( type => 'Text', label => 'Borough', disabled => 1 );
        has_field "postcode_$page" => ( type => 'Text', label => 'Postcode', required => 1 );
    }
};

has_field 'add_another' => (
    type => 'Submit',
    value => 'Add another',
    element_attr => {
        class => 'govuk-button govuk-button--secondary',
    },
);

1;

