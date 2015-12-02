package FixMyStreet::DB::ResultSet::Questionnaire;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub send_questionnaires {
    my ( $rs, $params ) = @_;
    require FixMyStreet::Script::Questionnaires;
    FixMyStreet::Script::Questionnaires::send($params);
}

sub timeline {
    my ( $rs, $restriction ) = @_;

    my $attrs;
    if (%$restriction) {
        $attrs = {
            -select => [qw/me.*/],
            prefetch => [qw/problem/],
        }
    }
    return $rs->search(
        {
            -or => {
                whenanswered => { '>=', \"current_timestamp-'7 days'::interval" },
                'me.whensent'  => { '>=', \"current_timestamp-'7 days'::interval" },
            },
            %{ $restriction },
        },
        $attrs
    );
}

sub summary_count {
    my ( $rs, $restriction ) = @_;

    my $params = {
        group_by => [ \'whenanswered is not null' ],
        select => [ \'(whenanswered is not null)', { count => 'me.id' } ],
        as => [qw/answered questionnaire_count/],
    };
    if (%$restriction) {
        $params->{join} = 'problem';
    }
    return $rs->search($restriction, $params);
}
1;
