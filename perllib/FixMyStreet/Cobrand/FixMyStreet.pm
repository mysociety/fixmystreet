package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

use constant COUNCIL_ID_BROMLEY => 2482;
use constant COUNCIL_ID_ISLEOFWIGHT => 2636;

sub on_map_default_status { return 'open'; }

# Show TfL pins as grey
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->to_body_named('TfL');
    return $self->next::method($p, $context);
}

# Special extra
sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web/fixmystreet.com' ),
    ];
}
sub path_to_email_templates {
    my ( $self, $lang_code ) = @_;
    return [
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com'),
    ];
}

# FixMyStreet should return all cobrands
sub restriction {
    return {};
}

# FixMyStreet needs to not show TfL reports...
sub problems_restriction {
    my ($self, $rs) = @_;
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    return $rs->search({ "$table.cobrand" => { '!=' => 'tfl' } });
}
sub problems_sql_restriction {
    my $self = shift;
    return "AND cobrand != 'tfl'";
}

sub relative_url_for_report {
    my ( $self, $report ) = @_;
    return $report->cobrand eq 'tfl' ? FixMyStreet::Cobrand::TfL->base_url : "";
}

sub munge_around_category_where {
    my ($self, $where) = @_;

    my $user = $self->{c}->user;
    my @iow = grep { $_->name eq 'Isle of Wight Council' } @{ $self->{c}->stash->{around_bodies} };
    return unless @iow;

    # display all the categories on Isle of Wight at the moment as there's no way to
    # do the expand bit later as we fetch it using ajax which uses a bounding box so
    # can't determine the body
    $where->{send_method} = [ { '!=' => 'Triage' }, undef ];
    return $where;
}

sub munge_reports_categories_list {
    my ($self, $categories) = @_;

    my %bodies = map { $_->body->name => $_->body } @$categories;
    if ( $bodies{'Isle of Wight Council'} ) {
        my $user = $self->{c}->user;
        my $b = $bodies{'Isle of Wight Council'};

        if ( $user && ( $user->is_superuser || $user->belongs_to_body( $b->id ) ) ) {
            @$categories = grep { !$_->send_method || $_->send_method ne 'Triage' } @$categories;
            return @$categories;
        }

        @$categories = grep { $_->send_method && $_->send_method eq 'Triage' } @$categories;
        return @$categories;
    }
}

sub munge_reports_area_list {
    my ($self, $areas) = @_;
    my $c = $self->{c};
    if ($c->stash->{body}->name eq 'TfL') {
        my %london_hash = map { $_ => 1 } FixMyStreet::Cobrand::TfL->london_boroughs;
        @$areas = grep { $london_hash{$_} } @$areas;
    }
}

sub munge_report_new_bodies {
    my ($self, $bodies) = @_;

    my %bodies = map { $_->name => 1 } values %$bodies;
    if ( $bodies{'TfL'} ) {
        # Presented categories vary if we're on/off a red route
        my $tfl = FixMyStreet::Cobrand::TfL->new({ c => $self->{c} });
        $tfl->munge_surrounding_london($bodies);
    }

    if ( $bodies{'Highways England'} ) {
        my $c = $self->{c};
        my $he = FixMyStreet::Cobrand::HighwaysEngland->new({ c => $c });
        my $on_he_road = $c->stash->{on_he_road} = $he->report_new_is_on_he_road;

        if (!$on_he_road) {
            %$bodies = map { $_->id => $_ } grep { $_->name ne 'Highways England' } values %$bodies;
        }
    }
}

sub munge_report_new_contacts {
    my ($self, $contacts) = @_;

    my %bodies = map { $_->body->name => $_->body } @$contacts;

    if ( $bodies{'Isle of Wight Council'} ) {
        my $user = $self->{c}->user;
        if ( $user && ( $user->is_superuser || $user->belongs_to_body( $bodies{'Isle of Wight Council'}->id ) ) ) {
            @$contacts = grep { !$_->send_method || $_->send_method ne 'Triage' } @$contacts;
            return;
        }

        @$contacts = grep { $_->send_method && $_->send_method eq 'Triage' } @$contacts;
    }

    if ( $bodies{'TfL'} ) {
        # Presented categories vary if we're on/off a red route
        my $tfl = FixMyStreet::Cobrand->get_class_for_moniker( 'tfl' )->new({ c => $self->{c} });
        $tfl->munge_red_route_categories($contacts);
    }

}

sub munge_load_and_group_problems {
    my ($self, $where, $filter) = @_;

    return unless $where->{category} && $self->{c}->stash->{body}->name eq 'Isle of Wight Council';

    my $iow = FixMyStreet::Cobrand->get_class_for_moniker( 'isleofwight' )->new({ c => $self->{c} });
    $where->{category} = $iow->expand_triage_cat_list($where->{category}, $self->{c}->stash->{body});
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

    my %errors;

    $c->stash->{dest} = $c->get_param('dest');

    if (!$c->get_param('dest')) {
        $errors{dest} = "Please enter who your message is for";
    } elsif ( $c->get_param('dest') eq 'council' || $c->get_param('dest') eq 'update' ) {
        $errors{not_for_us} = 1;
    }

    return %errors;
}

=head2 council_dashboard_hook

This is for council-specific dashboard pages, which can only be seen by
superusers and logged-in users with an email domain matching a body name.

=cut

sub council_dashboard_hook {
    my $self = shift;
    my $c = $self->{c};

    unless ( $c->user_exists ) {
        $c->res->redirect('/about/council-dashboard');
        $c->detach;
    }

    $c->forward('/admin/fetch_contacts');

    $c->detach('/reports/summary') if $c->user->is_superuser;

    my $body = $c->user->from_body || _user_to_body($c);
    if ($body) {
        # Matching URL and user's email body
        $c->detach('/reports/summary') if $body->id eq $c->stash->{body}->id;

        # Matched /a/ body, redirect to its summary page
        $c->stash->{body} = $body;
        $c->stash->{wards} = [ { name => 'summary' } ];
        $c->detach('/reports/redirect_body');
    }

    $c->res->redirect('/about/council-dashboard');
}

sub _user_to_body {
    my $c = shift;
    my $email = lc $c->user->email;
    return _email_to_body($c, $email);
}

sub _email_to_body {
    my ($c, $email) = @_;
    my ($domain) = $email =~ m{ @ (.*) \z }x;

    my @data = eval { FixMyStreet->path_to('../data/fixmystreet-councils.csv')->slurp };
    my $body;
    foreach (@data) {
        chomp;
        my ($d, $b) = split /\|/;
        if ($d eq $domain || $d eq $email) {
            $body = $b;
            last;
        }
    }
    # If we didn't find a lookup entry, default to the first part of the domain
    unless ($body) {
        $domain =~ s/\.gov\.uk$//;
        $body = ucfirst $domain;
    }

    $body = $c->forward('/reports/body_find', [ $body ]);
    return $body;
}

sub about_hook {
    my $self = shift;
    my $c = $self->{c};

    if ($c->stash->{template} eq 'about/council-dashboard.html') {
        $c->stash->{form_name} = $c->get_param('name') || '';
        $c->stash->{email} = $c->get_param('username') || '';
        if ($c->user_exists) {
            my $body = $c->user->from_body || _user_to_body($c);
            if ($body) {
                $c->stash->{body} = $body;
                $c->stash->{wards} = [ { name => 'summary' } ];
                $c->detach('/reports/redirect_body');
            }
        }
        if (my $email = $c->get_param('username')) {
            $email = lc $email;
            $email =~ s/\s+//g;
            my $body = _email_to_body($c, $email);
            if ($body) {
                # Send confirmation email (hopefully)
                $c->stash->{template} = 'auth/general.html';
                $c->detach('/auth/general', []);
            } else {
                $c->stash->{error} = 'bad_email';
            }
        }
    }
}

sub per_body_config {
    my ($self, $feature, $problem) = @_;

    # This is a hash of council name to match, and what to do
    my $cfg = $self->feature($feature) || {};

    my $value;
    my $body;
    foreach (keys %$cfg) {
        if ($problem->to_body_named($_)) {
            $value = $cfg->{$_};
            $body = $_;
            last;
        }
    }
    return ($value, $body);
}

sub updates_disallowed {
    my $self = shift;
    my ($problem) = @_;
    my $c = $self->{c};

    my ($type, $body) = $self->per_body_config('updates_allowed', $problem);
    $type //= '';

    if ($type eq 'none') {
        return 1;
    } elsif ($type eq 'staff') {
        # Only staff and superusers can leave updates
        my $staff = $c->user_exists && $c->user->from_body && $c->user->from_body->name =~ /$body/;
        my $superuser = $c->user_exists && $c->user->is_superuser;
        return 1 unless $staff || $superuser;
    }

    if ($type =~ /reporter/) {
        return 1 if !$c->user_exists || $c->user->id != $problem->user->id;
    }
    if ($type =~ /open/) {
        return 1 if $problem->is_fixed || $problem->is_closed;
    }

    return $self->next::method(@_);
}

sub suppress_reporter_alerts {
    my $self = shift;
    my $c = $self->{c};
    my $problem = $c->stash->{report};
    if ($problem->to_body_named('Westminster')) {
        return 1;
    }
    return 0;
}

sub must_have_2fa {
    my ($self, $user) = @_;
    return 1 if $user->is_superuser;
    return 1 if $user->from_body && $user->from_body->name eq 'TfL';
    return 0;
}

sub send_questionnaire {
    my ($self, $problem) = @_;
    my ($send, $body) = $self->per_body_config('send_questionnaire', $problem);
    return $send // 1;
}

sub update_email_shortlisted_user {
    my ($self, $update) = @_;
    FixMyStreet::Cobrand::TfL::update_email_shortlisted_user($self, $update);
}

sub manifest {
    return {
        related_applications => [
            { platform => 'play', url => 'https://play.google.com/store/apps/details?id=org.mysociety.FixMyStreet', id => 'org.mysociety.FixMyStreet' },
            { platform => 'itunes', url => 'https://apps.apple.com/gb/app/fixmystreet/id297456545', id => 'id297456545' },
        ],
    };
}

1;
