package FixMyStreet::DB::ResultSet::Contact;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;
use POSIX qw(strcoll);

sub me { join('.', shift->current_source_alias, shift || q{})  }

=head2 not_deleted

    $rs = $rs->not_deleted();

Filter down to not deleted contacts (so active or inactive).

=cut

sub not_deleted {
    my $rs = shift;
    return $rs->search( { $rs->me('state') => { -not_in => [ 'deleted', 'staff' ] } } );
}

sub not_deleted_admin {
    my $rs = shift;
    return $rs->search( { $rs->me('state') => { -not_in => [ 'deleted' ] } } );
}

sub active {
    my $rs = shift;
    $rs->search( { $rs->me('state') => [ 'unconfirmed', 'confirmed' ] } );
}

sub for_new_reports {
    my ($rs, $c, $bodies) = @_;
    my $params = {
        $rs->me('body_id') => [ keys %$bodies ],
    };

    if ($c->user_exists && $c->user->is_superuser) {
        # Everything normal OR any staff states
        $params->{$rs->me('state')} = [ 'unconfirmed', 'confirmed', 'staff' ];
    } elsif ($c->user_exists && $c->user->from_body) {
        # Everything normal OR staff state in the user body
        $params->{'-or'} = [
            $rs->me('state') => [ 'unconfirmed', 'confirmed' ],
            {
                $rs->me('body_id') => $c->user->from_body->id,
                $rs->me('state') => 'staff',
            },
        ];
    } else {
        $params->{$rs->me('state')} = [ 'unconfirmed', 'confirmed' ];
    }

    $rs->search($params, { prefetch => 'body' });
}

sub translated {
    my $rs = shift;
    my $schema = $rs->result_source->schema;
    $rs->search(undef, {
        '+columns' => { 'msgstr' => 'translations.msgstr' },
        join => 'translations',
        bind => [ 'category', $schema->lang, 'contact' ],
    });
}

sub all_sorted {
    my $rs = shift;

    my @contacts = $rs->translated->all;
    @contacts = sort {
        my $a_name = $a->get_extra_metadata('display_name') || $a->get_column('msgstr') || $a->category;
        my $b_name = $b->get_extra_metadata('display_name') || $b->get_column('msgstr') || $b->category;
        strcoll($a_name, $b_name)
    } @contacts;
    return @contacts;
}

sub summary_count {
    my ( $rs, $restriction ) = @_;

    return $rs->search(
        $restriction,
        {
            group_by => ['state'],
            select   => [ 'state', { count => 'id' } ],
            as       => [qw/state state_count/]
        }
    );
}

sub group_lookup {
    my $rs = shift;
    map {
        my $group = $_->get_extra_metadata('group') || '';
        $group = join(',', ref $group ? @$group : $group);
        $_->category => $group
    } $rs->all;
}

1;
