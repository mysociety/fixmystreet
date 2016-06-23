package FixMyStreet::Cobrand::AGDemo;
use base 'FixMyStreet::Cobrand::FixMyStreet';

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web/agdemo' ),
        FixMyStreet->path_to( 'templates/web/fixmystreet.com' ),
    ];
}

sub path_to_email_templates {
    my ( $self, $lang_code ) = @_;
    return [
        FixMyStreet->path_to( 'templates', 'email', 'agdemo'),
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com'),
    ];
}

sub ask_gender_question {
    return 0;
}


1;
