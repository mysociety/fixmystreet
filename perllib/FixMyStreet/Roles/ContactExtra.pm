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
    my $filters = {
        order_by => 'name',
        join => { $join_table => 'contact' },
        distinct => 1,
    };
    if ($category) {
        $attrs->{'contact.category'} = [ $category, undef ];
    }
    $rs->search($attrs, $filters);
}

sub by_categories {
    my ($rs, $area_id, @contacts) = @_;
    my %body_ids = map { $_->body_id => 1 } FixMyStreet::DB->resultset('BodyArea')->search({ area_id => $area_id });
    my @body_ids = keys %body_ids;
    my %extras = ();
    my @results = $rs->for_bodies(\@body_ids, undef);
    @contacts = grep { $body_ids{$_->body_id} } @contacts;

    foreach my $contact (@contacts) {
        my $join_table = $rs->join_table();
        my @ts = grep { !defined($_->$join_table->first) || $_->$join_table->find({contact_id => $contact->get_column('id')}) } @results;
        @ts = $rs->map_extras(@ts);
        $extras{$contact->category} = encode_json(\@ts);
    }

    return \%extras;
}

1;
