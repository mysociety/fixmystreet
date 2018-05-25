package FixMyStreet::Cobrand::Nditech;
use parent 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;
use FixMyStreet;

sub language_domain { 'autonditech' }

sub send_questionnaires { 0 }

sub report_form_extras {
    ( { name => 'phone_number', required => 0 } );
}

sub allow_anonymous_reports { 1 }

sub anonymous_account {
    return {
        name => 'Anonymous Submission',
        email => FixMyStreet->config('ANONYMOUS_REPORT_EMAIL')
    };
}

sub base_url_with_lang {
    my $self = shift;
    my $base = $self->base_url;
    my $lang = $mySociety::Locale::lang;
    if ($lang eq 'ar') {
        $base =~ s{en\.}{ar.};
    }
    return $base;
}

1;
