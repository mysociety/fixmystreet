package FixMyStreet::App::Controller::Claims;
use Moose;
use namespace::autoclean;

BEGIN { extends 'FixMyStreet::App::Controller::Form' }

use utf8;
use FixMyStreet::App::Form::Claims;

has feature => (
    is => 'ro',
    default => 'claims'
);

has form_class => (
    is => 'ro',
    default => 'FixMyStreet::App::Form::Claims',
);

has index_template => (
    is => 'ro',
    default => 'claims/index.html',
);


sub pre_form : Private {
    my ($self, $c) = @_;

    # Special button on map page to go back to where (hard as form wraps whole page)
    if ($c->get_param('goto-where')) {
        $c->set_param('goto', 'where');
        $c->set_param('process', '');
    }
}

sub process_claim : Private {
    my ($self, $c, $form) = @_;

    my $data = $form->saved_data;

    my $contributing_as_another_user = $c->user_exists && $c->user->from_body && $data->{email} && $c->user->email ne $data->{email};

    my $user = $c->user_exists
        ? $c->user->obj
        : $c->model('DB::User')->find_or_new( { email => $data->{email} } );
    $user->name($data->{name}) if $data->{name};
    $user->phone($data->{phone}) if $data->{phone};

    my $detail = "";
    for my $stage ( @{ $form->fields_for_display } ) {
        next if $stage->{hide};
        for my $field ( @{ $stage->{fields} } ) {
            next if $field->{hide};
            $detail .= "$field->{desc}: " . $field->{pretty} . "\n";
        }
    }

    my %shared = (
        state => 'unconfirmed',
        cobrand => $c->cobrand->moniker,
        cobrand_data => 'claim',
        lang => $c->stash->{lang_code},
        user => $user,
        name => $user->name,
        anonymous => 0,
        extra => $data,
    );

    my $object = $c->model('DB::Problem')->new({
        non_public => 1,
        category => 'Claim',
        used_map => 1,
        title => 'Claim',
        detail => $detail,
        postcode => '',
        latitude => $data->{latitude},
        longitude => $data->{longitude},
        areas => '',
        send_questionnaire => 0,
        bodies_str => $c->cobrand->body->id,
        photo => $data->{photos},
        %shared,
    });

    $c->stash->{detail} = $detail;

    if ($contributing_as_another_user) {
        $object->set_extra_metadata( contributed_as => 'another_user');
        $object->set_extra_metadata( contributed_by => $c->user->id );
    } elsif ( !$object->user->in_storage ) {
        $object->user->insert();
    } elsif ( $c->user && $object->user->id == $c->user->id ) {
        $object->user->update();
    } else {
        $object->user->discard_changes();
    }

    $object->confirm;
    $object->insert;
    $object->create_related_things();
    my $template = $object->response_templates->search({ 'me.state' => $object->state })->first;
    $c->stash->{auto_response} = $template->text if $template;
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
