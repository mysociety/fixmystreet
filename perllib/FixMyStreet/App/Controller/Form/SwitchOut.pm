package FixMyStreet::App::Controller::Form::SwitchOut;
use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::App::Controller::Form' }

use utf8;
use Try::Tiny;
use FixMyStreet::App::Form::TfL::SwitchOut;

has feature => ( is => 'ro', default => 'tfl_switch_out' );

has form_class => ( is => 'ro', default => 'FixMyStreet::App::Form::TfL::SwitchOut' );

has index_template => ( is => 'ro', default => 'switchout/index.html' );

sub pre_form : Private {
    my ($self, $c) = @_;

    # Special button on map page to go back to where (hard as form wraps whole page)
    if ($c->get_param('goto-where')) {
        $c->set_param('goto', 'where');
        $c->set_param('process', '');
    }
}

sub process_switchout : Private {
    my ($self, $c, $form) = @_;

    my $data = $form->saved_data;

    # Handle staff submitting on behalf of another user
    my $contributing_as_another_user = $c->user_exists
        && $c->user->from_body
        && $data->{email}
        && $c->user->email ne $data->{email};

    # Find or create user
    my $user = $c->user_exists
        ? $c->user->obj
        : $c->model('DB::User')->find_or_new({ email => $data->{email} });
    $user->name($data->{name}) if $data->{name};
    $user->phone($data->{phone}) if $data->{phone};

    # Build detail string from form fields, grouped by section
    my $detail = "";
    if ($form->can('fields_for_display')) {
        my @sections;
        for my $stage (@{ $form->fields_for_display }) {
            next if $stage->{hide};
            my @visible_fields = grep { !$_->{hide} } @{ $stage->{fields} };
            next unless @visible_fields;

            my $section = "";
            $section .= "[$stage->{title}]\n" if $stage->{title};
            for my $field (@visible_fields) {
                my $pretty = $field->{pretty};
                my $desc = $field->{desc};
                $desc .= ':' unless !$desc || $desc =~ /[?:.]$/;
                $desc .= $field->{name} eq 'terms_accepted' ? "\n" : ' ';

                $section .= "$desc$pretty\n";
            }
            push @sections, $section;
        }
        $detail = join("\n", @sections);
    }

    my $category = "Switch out application";

    my $latitude = $data->{latitude};
    my $longitude = $data->{longitude};
    my $areas = try {
        my $areas = FixMyStreet::MapIt::call('point', "4326/$longitude,$latitude", type => 'LBO');
        ',' . join(',', sort keys %$areas) . ',';
    } || "";

    my $problem = $c->model('DB::Problem')->new({
        non_public         => 1,
        category           => $category,
        used_map           => $data->{latitude} ? 1 : 0,
        title              => $category,
        detail             => $detail,
        postcode           => $data->{postcode} || '',
        latitude           => $latitude,
        longitude          => $longitude,
        areas              => $areas,
        send_questionnaire => 0,
        bodies_str         => $c->cobrand->body->id,
        photo              => $data->{photos},
        state              => 'unconfirmed',
        cobrand            => $c->cobrand->moniker,
        cobrand_data       => 'switchout',
        lang               => $c->stash->{lang_code},
        user               => $user,
        name               => $user->name || '',
        anonymous          => 0,
        extra              => $data,
    });
    $problem->set_extra_metadata(phone => $data->{phone}); # Make sure stored somewhere

    $c->stash->{detail} = $detail;

    # Handle user creation/association
    if ($contributing_as_another_user) {
        $problem->set_extra_metadata(contributed_as => 'another_user');
        $problem->set_extra_metadata(contributed_by => $c->user->id);
    } elsif (!$problem->user->in_storage) {
        $problem->user->insert();
    } elsif ($c->user && $problem->user->id == $c->user->id) {
        $problem->user->update();
    } else {
        $problem->user->discard_changes();
    }

    $problem->confirm;
    $problem->insert;
    $problem->create_related_things();

    $c->stash->{problem} = $problem;
    $c->stash->{reference} = 'FMS' . $problem->id;

    return 1;
}

=head2 view

When someone views their switch out application, we reconstruct the
summary page they were shown during the application.

=cut

sub view : Private {
    my ($self, $c) = @_;
    my $p = $c->stash->{problem};
    $c->forward('/auth/get_csrf_token');
    $c->forward('form');
    $c->stash->{form}->saved_data($p->extra);
    $c->stash->{template} = 'switchout/summary.html';
}

=head2 pdf

We want to generate a PDF version of the summary
page they were shown during the application.

=cut

sub pdf : Local : Args(1) {
    my ($self, $c, $id) = @_;
    my $p = FixMyStreet::DB->resultset("Problem")->find($id);

    my $token_ok = ($c->get_param('token') || '') eq ($p ? $p->confirmation_token : '');
    $c->detach('/page_error_404_not_found')
        unless $p && (
            $token_ok
            || ($c->user_exists && ($c->user->is_superuser || $c->user->id == $p->user_id))
        );

    my $pdf = FixMyStreet::App::Form::TfL::SwitchOut->generate_pdf($p);
    $c->detach('/page_error_404_not_found') unless $pdf;

    $c->res->content_type('application/pdf');
    $c->res->body($pdf);
}

__PACKAGE__->meta->make_immutable;

1;

