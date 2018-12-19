package FixMyStreet::Cobrand::FixMyStreet;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

use mySociety::Random;

use constant COUNCIL_ID_BROMLEY => 2482;

sub on_map_default_status { return 'open'; }

sub enable_category_groups { 1 }

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
        if ($d eq $domain) {
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

1;
