package FixMyStreet::Roles::DB::ContactExtra;

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

    my $i = 0;
    my %lookup;
    my $join_table = $rs->join_table();
    foreach my $result (@results) {
        if ($result->$join_table == 0) { # There's no category at all on this defect type/template/priority
            push @{$lookup{_all}}, [ $i, $result ];
        } else {
            for ($result->$join_table) {
                push @{$lookup{$_->contact_id}}, [ $i, $result ];
            }
        }
        $i++;
    }

    foreach my $contact (@contacts) {
        my $id = $contact->get_column('id');
        my @ts = map { $_->[1] } sort { $a->[0] <=> $b->[0] } @{$lookup{_all}}, @{$lookup{$id}};
        @ts = $rs->map_extras(\%params, @ts);
        $extras{$contact->category} = JSON::XS->new->encode(\@ts);
    }

    return \%extras;
}

1;
