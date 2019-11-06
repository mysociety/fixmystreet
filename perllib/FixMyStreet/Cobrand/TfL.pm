package FixMyStreet::Cobrand::TfL;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use POSIX qw(strcoll);

use FixMyStreet::MapIt;

sub council_area_id { return [
    2511, 2489, 2494, 2488, 2482, 2505, 2512, 2481, 2484, 2495,
    2493, 2508, 2502, 2509, 2487, 2485, 2486, 2483, 2507, 2503,
    2480, 2490, 2492, 2500, 2510, 2497, 2499, 2491, 2498, 2506,
    2496, 2501, 2504
]; }
sub council_area { return 'TfL'; }
sub council_name { return 'TfL'; }
sub council_url { return 'tfl'; }
sub area_types  { [ 'LBO' ] }
sub is_council { 0 }

sub send_questionnaires { 0 }

sub area_check {
    my ( $self, $params, $context ) = @_;

    my $councils = $params->{all_areas};
    my $council_match = grep { $councils->{$_} } @{ $self->council_area_id };

    return 1 if $council_match;
    return ( 0, $self->area_check_error_message($params, $context) );
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a London postcode, or street name and area';
}

sub privacy_policy_url { 'https://tfl.gov.uk/corporate/privacy-and-cookies/reporting-street-problems' }

sub about_hook {
    my $self = shift;
    my $c = $self->{c};

    if ($c->stash->{template} eq 'about/privacy.html') {
        $c->res->redirect($self->privacy_policy_url);
        $c->detach;
    }
}

sub body {
    # Overridden because UKCouncils::body excludes TfL
    FixMyStreet::DB->resultset('Body')->search({ name => 'TfL' })->first;
}

# These need to be overridden so the method in UKCouncils doesn't create
# a fixmystreet.com link (because of the false-returning owns_problem call)
sub relative_url_for_report { "" }
sub base_url_for_report {
    my $self = shift;
    return $self->base_url;
}

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( { 'body.name' => 'TfL' } );
}

sub lookup_by_ref_regex {
    return qr/^\s*((?:FMS\s*)?\d+)\s*$/i;
}

sub lookup_by_ref {
    my ($self, $ref) = @_;

    if ( $ref =~ s/^\s*FMS\s*//i ) {
        return { 'id' => $ref };
    }

    return 0;
}

sub report_sent_confirmation_email { 'id' }

sub report_age { '6 weeks' }

sub password_expiry {
    return if FixMyStreet->test_mode;
    # uncoverable statement
    86400 * 365
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'green' if $p->is_closed;
    return 'green' if $p->is_fixed;
    return 'red' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
    return undef unless defined $user->from_body;
    return $user->from_body->name eq 'TfL';
}

sub fetch_area_children {
    my $self = shift;

    my $areas = FixMyStreet::MapIt::call('areas', $self->area_types);
    foreach (keys %$areas) {
        $areas->{$_}->{name} =~ s/\s*(Borough|City|District|County) Council$//;
    }
    return $areas;
}

sub available_permissions {
    my $self = shift;

    my $perms = $self->next::method();

    delete $perms->{Problems}->{report_edit_priority};
    delete $perms->{Bodies}->{responsepriority_edit};

    return $perms;
}

sub must_have_2fa {
    my ($self, $user) = @_;

    require Net::Subnet;
    my $ips = $self->feature('internal_ips');
    my $is_internal_network = Net::Subnet::subnet_matcher(@$ips);

    my $ip = $self->{c}->req->address;
    return 'skip' if $is_internal_network->($ip);
    return 1 if $user->is_superuser;
    return 1 if $user->from_body && $user->from_body->name eq 'TfL';
    return 0;
}

sub update_email_shortlisted_user {
    my ($self, $update) = @_;
    my $c = $self->{c};
    my $shortlisted_by = $update->problem->shortlisted_user;
    if ($shortlisted_by && $shortlisted_by->from_body && $shortlisted_by->from_body->name eq 'TfL' && $shortlisted_by->id ne $update->user_id) {
        $c->send_email('alert-update.txt', {
            to => [ [ $shortlisted_by->email, $shortlisted_by->name ] ],
            report => $update->problem,
            problem_url => $c->cobrand->base_url_for_report($update->problem) . $update->problem->url,
            data => [ {
                item_photo => $update->photo,
                item_text => $update->text,
                item_name => $update->name,
                item_anonymous => $update->anonymous,
            } ],
        });
    }
}

sub report_new_munge_before_insert {
    my ($self, $report) = @_;

    # Sets the safety critical flag on this report according to category/extra
    # fields selected.

    my $safety_critical = 0;
    my $categories = $self->feature('safety_critical_categories');
    my $category = $categories->{$report->category};
    if ( ref $category eq 'HASH' ) {
        # report is safety critical if any of its field values match
        # the critical values from the config
        for my $code (keys %$category) {
            my $value = $report->get_extra_field_value($code);
            my %critical_values = map { $_ => 1 } @{ $category->{$code} };
            $safety_critical ||= $critical_values{$value};
        }
    } elsif ($category) {
        # the entire category is safety critical
        $safety_critical = 1;
    }

    my $extra = $report->get_extra_fields;
    @$extra = grep { $_->{name} ne 'safety_critical' } @$extra;
    push @$extra, { name => 'safety_critical', value => $safety_critical ? 'yes' : 'no' };
    $report->set_extra_fields(@$extra);
}

1;
