package FixMyStreet::Roles::ContactExtra;

use Moo::Role;
use JSON::MaybeXS;

requires 'join_table', 'map_extras';

sub for_bodies {
    my ($rs, $bodies, $category) = @_;
    my $join_table = $rs->join_table();
    my $attrs = {
        'me.body_id' => $bodies,
    };
    my $order = $rs->can('name_column') ? $rs->name_column() : 'name';
    my $filters = {
        order_by => $order,
        join => { $join_table => 'contact' },
        prefetch => $join_table,
        distinct => 1,
    };
    if ($category) {
        $attrs->{'contact.category'} = [ $category, undef ];
    }
    $rs->search($attrs, $filters);
}

sub by_categories {
    my ($rs, $contacts, %params) = @_;

    my %body_ids = ();
    if ( $params{body_id} ) {
        %body_ids = ( $params{body_id} => 1 );
    } else {
        %body_ids = map { $_->body_id => 1 } FixMyStreet::DB->resultset('BodyArea')->search({ area_id => $params{area_id} });
    }
    my @contacts = @$contacts;
    my @body_ids = keys %body_ids;
    my %extras = ();
    my @results = $rs->for_bodies(\@body_ids, undef);
    @contacts = grep { $body_ids{$_->body_id} } @contacts;

    foreach my $contact (@contacts) {
        my $join_table = $rs->join_table();
        my @ts = grep {
               $_->$join_table == 0 # There's no category at all on this defect type/template/priority
            || (grep { $_->contact_id == $contact->get_column('id') } $_->$join_table)
        } @results;
        @ts = $rs->map_extras(@ts);
        $extras{$contact->category} = encode_json(\@ts);
    }

    return \%extras;
}

1;
