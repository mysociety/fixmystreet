package FixMyStreet::App::Controller::Licence;
use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::App::Controller::Form' }

use utf8;

# Discover and load all form classes in FixMyStreet::App::Form::Licence::*
my @ALL_FORM_CLASSES;
BEGIN {
    require Module::Pluggable;
    Module::Pluggable->import(
        search_path => 'FixMyStreet::App::Form::Licence',
        sub_name    => '_form_classes',
        require     => 1,
    );
    @ALL_FORM_CLASSES = __PACKAGE__->_form_classes;
}

has feature => ( is => 'ro', default => 'licencing_forms' );

has index_template => ( is => 'ro', default => 'licence/index.html' );

# Build licence types from discovered form classes
sub licence_types {
    my $self = shift;
    my %types;
    for my $class (@ALL_FORM_CLASSES) {
        next unless $class->can('type') && $class->can('name');
        my $type = $class->type;
        $types{$type} = {
            class => $class,
            name  => $class->name,
        };
    }
    return \%types;
}

# Override parent Form.pm's index to 404 - you must specify a licence type
# (Without this, the inherited index would try to load a non-existent form)
sub index : Path : Args(0) {
    my ($self, $c) = @_;
    $c->detach('/page_error_404_not_found');
}

# GET/POST /licence/:type - show/process a specific licence form
sub show : Path : Args(1) {
    my ($self, $c, $type) = @_;

    my $licence_config = $self->licence_types->{lc $type}
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

    # Build detail string from form fields
    my $detail = "";
    if ($form->can('fields_for_display')) {
        for my $stage (@{ $form->fields_for_display }) {
            next if $stage->{hide};
            for my $field (@{ $stage->{fields} }) {
                next if $field->{hide};
                $detail .= "$field->{desc}: " . $field->{pretty} . "\n";
            }
        }
    }

    my $category = "$name licence";

    my %shared = (
        state        => 'unconfirmed',
        cobrand      => $c->cobrand->moniker,
        cobrand_data => 'licence',
        lang         => $c->stash->{lang_code},
        user         => $user,
        name         => $user->name || '',
        anonymous    => 0,
        extra        => $data,
    );

    # Default to central London (Trafalgar Square) if geocoding didn't provide coordinates.
    # This ensures the report can be viewed without National Grid conversion errors.
    my $latitude = $data->{latitude} || 51.508;
    my $longitude = $data->{longitude} || -0.128;

    my $problem = $c->model('DB::Problem')->new({
        non_public       => 1,
        category         => $category,
        used_map         => $data->{latitude} ? 1 : 0,
        title            => $category,
        detail           => $detail,
        postcode         => $data->{postcode} || '',
        latitude         => $latitude,
        longitude        => $longitude,
        areas            => '',
        send_questionnaire => 0,
        bodies_str       => $c->cobrand->body->id,
        photo            => $data->{photos},
        %shared,
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

    # Check for auto-response template
    my $template = $problem->response_templates->search({ 'me.state' => $problem->state })->first;
    $c->stash->{auto_response} = $template->text if $template;

    $c->stash->{problem} = $problem;
    $c->stash->{reference} = 'FMS' . $problem->id;

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
