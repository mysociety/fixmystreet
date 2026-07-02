package FixMyStreet::App::Form::Licence::Fields::MultipleLocations;

use utf8;
use HTML::FormHandler::Moose::Role;

=head1 NAME

FixMyStreet::App::Form::Licence::Fields::MultipleLocations - Further location pages for licence forms

=head1 DESCRIPTION

Provides further pages of location fields for TfL licence forms.

=cut

sub location_page_fields {
    my $args = shift;
    my $page = $args->{page};
    my $next = 'dates';
    my $fields = ["building_name_number_$page", "street_name_$page", "borough_$page", "postcode_$page", 'continue'];
    if ($page < $args->{pages}) {
        $next = sub { $_[1]->{add_another} ? 'location_' . ($page+1) : 'dates' };
        push @$fields, 'add_another';
    }

    return (
        step_number => 1,
        fields => $fields,
        update_field_list => sub {
            my $data = $_[0]->saved_data;
            return {
                "street_name_$page" => { default => $data->{street_name} },
                "borough_$page" => { default => $data->{borough} },
            }
        },
        title => "$args->{title} ($page)",
        intro => $args->{template},
        next => $next,
        tags => { hide => sub { !$_[0]->form->saved_data->{"building_name_number_$page"} } },
    );
}

1;
