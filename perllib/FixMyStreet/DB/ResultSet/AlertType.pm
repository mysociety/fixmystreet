package FixMyStreet::DB::ResultSet::AlertType;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub email_alerts ($) {
    my ( $rs ) = @_;
    require FixMyStreet::Script::Alerts;
    FixMyStreet::Script::Alerts::send(@_);
}

1;
