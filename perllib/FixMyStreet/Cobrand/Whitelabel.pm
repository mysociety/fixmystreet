package FixMyStreet::Cobrand::Whitelabel;
use base 'FixMyStreet::Cobrand::FixMyStreet';

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web/whitelabel' ),
        FixMyStreet->path_to( 'templates/web/fixmystreet.com' ),
    ];
}

sub path_to_email_templates {
    my ( $self, $lang_code ) = @_;
    return [
        FixMyStreet->path_to( 'templates', 'email', 'whitelabel'),
        FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com'),
    ];
}

sub ask_gender_question {
    return 0;
}


1;
