package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::Default';

# FixMyStreet should return all cobrands
sub restriction {
    return {};
}

sub get_council_sender {
    my ( $self, $area_id, $area_info ) = @_;

    my $send_method;

    my $council_config = FixMyStreet::App->model("DB::Open311conf")->search( { area_id => $area_id } )->first;
    $send_method = $council_config->send_method if $council_config;

    return $send_method if $send_method;

    return 'London' if $area_info->{type} eq 'LBO';

    return 'Email';
}

sub generate_problem_banner {
    my ( $self, $problem ) = @_;

    my $banner = {};
    if ( $problem->is_open && time() - $problem->lastupdate_local->epoch > 8 * 7 * 24 * 60 * 60 )
    {
        $banner->{id}   = 'unknown';
        $banner->{text} = _('Unknown');
    }
    if ($problem->is_fixed) {
        $banner->{id} = 'fixed';
        $banner->{text} = _('Fixed');
    }
    if ($problem->is_closed) {
        $banner->{id} = 'closed';
        $banner->{text} = _('Closed');
    }

    if ( grep { $problem->state eq $_ } ( 'investigating', 'in progress', 'planned' ) ) {
        $banner->{id} = 'progress';
        $banner->{text} = _('In progress');
    }

    return $banner;
}

sub process_extras {
    my $self     = shift;
    my $ctx      = shift;
    my $contacts = shift;
    my $extra    = shift;

    if ( $contacts->[0]->area_id == 2482 ) {
        for my $field ( qw/ fms_extra_title / ) {
            my $value = $ctx->request->param( $field );

            if ( !$value ) {
                $ctx->stash->{field_errors}->{ $field } = _('This information is required');
            }
            push @$extra, {
                name => $field,
                description => uc( $field),
                value => $value || '',
            };
        }

        if ( $ctx->request->param('fms_extra_title') ) {
            $ctx->stash->{fms_extra_title} = $ctx->request->param('fms_extra_title');
            $ctx->stash->{extra_name_info} = 1;
        }
    }
}
1;

