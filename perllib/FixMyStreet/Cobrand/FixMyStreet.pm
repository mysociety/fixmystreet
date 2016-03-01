package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::UK';
use mySociety::Gaze;

use constant COUNCIL_ID_BROMLEY => 2482;

# Special extra
sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web/fixmystreet.com' )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

# FixMyStreet should return all cobrands
sub restriction {
    return {};
}

sub admin_base_url {
    return 'https://secure.mysociety.org/admin/bci';
}

sub title_list {
    my $self = shift;
    my $areas = shift;
    my $first_area = ( values %$areas )[0];

    return ["MR", "MISS", "MRS", "MS", "DR"] if $first_area->{id} eq COUNCIL_ID_BROMLEY;
    return undef;
}

sub extra_contact_validation {
    my $self = shift;
    my $c = shift;

    # Don't care about dest if reporting abuse
    return () if $c->stash->{problem};

    my %errors;

    $c->stash->{dest} = $c->get_param('dest');

    $errors{dest} = "Please enter who your message is for"
        unless $c->get_param('dest');

    if ( $c->get_param('dest') eq 'council' || $c->get_param('dest') eq 'update' ) {
        $errors{not_for_us} = 1;
    }

    return %errors;
}

sub get_country_for_ip_address {
    my $self = shift;
    my $ip = shift;

    return mySociety::Gaze::get_country_from_ip($ip);
}

sub report_form_extras {
    ( { name => 'gender', required => 0 }, { name => 'variant', required => 0 } )
}

sub ask_gender_question {
    my $self = shift;

    return 1 unless $self->{c}->user;

    my $reports = $self->{c}->model('DB::Problem')->search({
        user_id => $self->{c}->user->id,
        extra => { like => '%gender%' }
    }, { order_by => { -desc => 'id' } });

    while (my $report = $reports->next) {
        my $gender = $report->get_extra_metadata('gender');
        return 0 if $gender =~ /female|male|other|unknown/;
    }
    return 1;
}

1;

