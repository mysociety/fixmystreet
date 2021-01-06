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


sub process_claim : Private {
    my ($self, $c, $form) = @_;

    my $data = $form->saved_data;

    my $report_id = $data->{report_id};

    my $detail = "";

    for my $stage ( @{ $form->fields_for_display } ) {
        next if $stage->{hide};
        for my $field ( @{ $stage->{fields} } ) {
            next if $field->{hide};
            $detail .= "$field->{desc}: " . $field->{pretty} . "\n";
        }
    }

    my $user = $c->user_exists
        ? $c->user->obj
        : $c->model('DB::User')->find_or_new( { email => $data->{email} } );
    $user->name($data->{name}) if $data->{name};
    $user->phone($data->{phone}) if $data->{phone};

    my $report;
    if ( $report_id ) {
        $report = FixMyStreet::DB->resultset('Problem')->find($report_id);
    } else {
        $report = $c->model('DB::Problem')->new({
            non_public => 1,
            state => 'unconfirmed',
            cobrand => $c->cobrand->moniker,
            cobrand_data => 'noise',
            lang => $c->stash->{lang_code},
            user => $user, # XXX
            name => $data->{name},
            anonymous => 0,
            extra => $data,
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
        });
    }

    $c->stash->{detail} = $detail;

}

__PACKAGE__->meta->make_immutable;

1;
