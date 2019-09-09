package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

use mySociety::Random;

use constant COUNCIL_ID_BROMLEY => 2482;
use constant COUNCIL_ID_ISLEOFWIGHT => 2636;

sub on_map_default_status { return 'open'; }

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

sub add_response_headers {
    my $self = shift;
    # uncoverable branch true
    return if $self->{c}->debug;
    my $csp_nonce = $self->{c}->stash->{csp_nonce} = unpack('h*', mySociety::Random::random_bytes(16, 1));
    $self->{c}->res->header('Content-Security-Policy', "script-src 'self' www.google-analytics.com www.googleadservices.com 'unsafe-inline' 'nonce-$csp_nonce'")
}

# FixMyStreet should return all cobrands
sub restriction {
    return {};
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

sub munge_category_list {
    my ($self, $options, $contacts, $extras) = @_;

    # No TfL Traffic Lights category in Hounslow
    my %bodies = map { $_->body->name => $_->body } @$contacts;
    if ( $bodies{'Hounslow Borough Council'} ) {
        @$options = grep { ($_->{category} || $_->category) !~ /^Traffic lights$/i } @$options;
    }

    if ( $bodies{'Isle of Wight Council'} ) {
        my $user = $self->{c}->user;
        if ( $user && ( $user->is_superuser || $user->belongs_to_body( $bodies{'Isle of Wight Council'}->id ) ) ) {
            @$contacts = grep { !$_->send_method || $_->send_method ne 'Triage' } @$contacts;
            my $seen = { map { $_->category => 1 } @$contacts };
            @$options = grep { my $c = ($_->{category} || $_->category); $c =~ 'Pick a category' || $seen->{ $c } } @$options;
            return;
        }

        @$contacts = grep { $_->send_method && $_->send_method eq 'Triage' } @$contacts;
        my $seen = { map { $_->category => 1 } @$contacts };
        @$options = grep { my $c = ($_->{category} || $_->category); $c =~ 'Pick a category' || $seen->{ $c } } @$options;
    }
}

sub munge_load_and_group_problems {
    my ($self, $where, $filter) = @_;

    return unless $where->{category} && $self->{c}->stash->{body}->name eq 'Isle of Wight Council';

    my $cat_names = $self->expand_triage_cat_list($where->{category});

    $where->{category} = $cat_names;
    my $problems = $self->problems->search($where, $filter);
    return $problems;
}

sub expand_triage_cat_list {
    my ($self, $categories) = @_;

    my $b = $self->{c}->stash->{body};

    my $all_cats = $self->{c}->model('DB::Contact')->not_deleted->search(
        {
            body_id => $b->id,
            send_method => [{ '!=', 'Triage'}, undef]
        }
    );

    my %group_to_category;
    while ( my $cat = $all_cats->next ) {
        next unless $cat->get_extra_metadata('group');
        my $groups = $cat->get_extra_metadata('group');
        $groups = ref $groups eq 'ARRAY' ? $groups : [ $groups ];
        for my $group ( @$groups ) {
            $group_to_category{$group} //= [];
            push @{ $group_to_category{$group} }, $cat->category;
        }
    }

    my $cats = $self->{c}->model('DB::Contact')->not_deleted->search(
        {
            body_id => $b->id,
            category => $categories
        }
    );

    my @cat_names;
    while ( my $cat = $cats->next ) {
        if ( $cat->send_method && $cat->send_method eq 'Triage' ) {
            # include the category itself
            push @cat_names, $cat->category;
            push @cat_names, @{ $group_to_category{$cat->category} } if $group_to_category{$cat->category};
        } else {
            push @cat_names, $cat->category;
        }
    }

    return \@cat_names;
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
                $c->detach('/auth/general');
            } else {
                $c->stash->{error} = 'bad_email';
            }
        }
    }
}

sub updates_disallowed {
    my $self = shift;
    my ($problem) = @_;
    my $c = $self->{c};

    # This is a hash of council name to match, and what to do
    my $cfg = $self->feature('updates_allowed') || {};

    my $type = '';
    my $body;
    foreach (keys %$cfg) {
        if ($problem->to_body_named($_)) {
            $type = $cfg->{$_};
            $body = $_;
            last;
        }
    }

    if ($type eq 'none') {
        return 1;
    } elsif ($type eq 'staff') {
        # Only staff and superusers can leave updates
        my $staff = $c->user_exists && $c->user->from_body && $c->user->from_body->name =~ /$body/;
        my $superuser = $c->user_exists && $c->user->is_superuser;
        return 1 unless $staff || $superuser;
    } elsif ($type eq 'reporter') {
        return 1 if !$c->user_exists || $c->user->id != $problem->user->id;
    } elsif ($type eq 'open') {
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

1;
