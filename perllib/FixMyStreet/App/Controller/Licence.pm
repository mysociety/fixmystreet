package FixMyStreet::App::Controller::Licence;
use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::App::Controller::Form' }

use utf8;
use FixMyStreet::App::Form::Licence;

has feature => ( is => 'ro', default => 'licencing_forms' );

has index_template => ( is => 'ro', default => 'licence/index.html' );

# Override parent Form.pm's index to 404 - you must specify a licence type
# (Without this, the inherited index would try to load a non-existent form)
sub index : Path : Args(0) {
    my ($self, $c) = @_;
    $c->detach('/page_error_404_not_found');
}

# GET/POST /licence/:type - show/process a specific licence form
sub show : Path : Args(1) {
    my ($self, $c, $type) = @_;

    my $licence_config = FixMyStreet::App::Form::Licence->licence_types->{lc $type}
        or $c->detach('/page_error_404_not_found');

    $c->stash->{form_class} = $licence_config->{class};
    $c->stash->{licence_type} = lc $type;
    $c->stash->{licence_name} = $licence_config->{name};

    $c->forward('/auth/get_csrf_token');
    $c->forward('form');
}

sub process_licence : Private {
    my ($self, $c, $form) = @_;

    my $data = $form->saved_data;
    my $type = $c->stash->{licence_type};
    my $name = $c->stash->{licence_name};
    $data->{licence_type} = $type;

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
                $section .= "$field->{desc}: $field->{pretty}\n";
            }
            push @sections, $section;
        }
        $detail = join("\n", @sections);
    }

    my $category = "$name licence";

    # Default to central London (Trafalgar Square) if geocoding didn't provide coordinates.
    # This ensures the report can be viewed without National Grid conversion errors.
    my $latitude = $data->{latitude} || 51.508;
    my $longitude = $data->{longitude} || -0.128;

    my $problem = $c->model('DB::Problem')->new({
        non_public         => 1,
        category           => $category,
        used_map           => $data->{latitude} ? 1 : 0,
        title              => $category,
        detail             => $detail,
        postcode           => $data->{postcode} || '',
        latitude           => $latitude,
        longitude          => $longitude,
        areas              => '',
        send_questionnaire => 0,
        bodies_str         => $c->cobrand->body->id,
        photo              => $data->{photos},
        state              => 'unconfirmed',
        cobrand            => $c->cobrand->moniker,
        cobrand_data       => 'licence',
        lang               => $c->stash->{lang_code},
        user               => $user,
        name               => $user->name || '',
        anonymous          => 0,
        extra              => $data,
    });

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

When someone views their licence application, we reconstruct the
summary page they were shown during the application.

=cut

sub view : Private {
    my ($self, $c) = @_;
    my $p = $c->stash->{problem};
    my $type = $p->get_extra_metadata('licence_type');
    $c->forward('show', [ $type ]);
    $c->stash->{form}->saved_data($p->extra);
    $c->stash->{template} = 'licence/summary.html';
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

    my $pdf = FixMyStreet::App::Form::Licence->generate_pdf($p);
    $c->detach('/page_error_404_not_found') unless $pdf;

    $c->res->content_type('application/pdf');
    $c->res->body($pdf);
}

__PACKAGE__->meta->make_immutable;

1;
