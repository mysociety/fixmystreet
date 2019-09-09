package FixMyStreet::Cobrand::IsleOfWight;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2636 }
sub council_area { 'Isle of Wight' }
sub council_name { 'Island Roads' }
sub council_url { 'isleofwight' }
sub all_reports_single_body { { name => "Isle of Wight Council" } }
sub link_to_council_cobrand { "Island Roads" }

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter an ' . $self->council_area . ' postcode, or street name and area';
}

sub admin_user_domain { ('islandroads.com') }

sub on_map_default_status { 'open' }

sub send_questionnaires { 0 }

sub report_sent_confirmation_email { 'external_id' }

sub map_type { 'IsleOfWight' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '50.675761,-1.296571',
        bounds => [ 50.574653, -1.591732, 50.767567, -1.062957 ],
    };
}

sub updates_disallowed {
    my ($self, $problem) = @_;

    my $c = $self->{c};
    return 0 if $c->user_exists && $c->user->id eq $problem->user->id;
    return 1;
}

sub get_geocoder { 'OSM' }

sub open311_pre_send {
    my ($self, $row, $open311) = @_;

    return unless $row->extra;
    my $extra = $row->get_extra_fields;
    if (@$extra) {
        @$extra = grep { $_->{name} ne 'urgent' } @$extra;
        $row->set_extra_fields(@$extra);
    }
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra,
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail };

    $row->set_extra_fields(@$extra);
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    if ($comment->mark_fixed) {
        $params->{description} = "[The customer indicated that this issue had been fixed]\n\n" . $params->{description};
    }

    if ( $comment->get_extra_metadata('triage_report') ) {
        $params->{description} = "Triaged by " . $comment->user->name . ' (' . $comment->user->email . "). " . $params->{description};
    }

    $params->{description} = "FMS-Update: " . $params->{description};
}

# this handles making sure the user sees the right categories on the new report page
sub munge_reports_category_list {
    my ($self, $categories) = @_;

    my $user = $self->{c}->user;
    my %bodies = map { $_->body->name => $_->body } @$categories;
    my $b = $bodies{'Isle of Wight Council'};

    if ( $user && ( $user->is_superuser || $user->belongs_to_body( $b->id ) ) ) {
        @$categories = grep { !$_->send_method || $_->send_method ne 'Triage' } @$categories;
        return @$categories;
    }

    @$categories = grep { $_->send_method && $_->send_method eq 'Triage' } @$categories;
    return @$categories;
}

sub munge_category_list {
    my ($self, $options, $contacts, $extras) = @_;

    my $user = $self->{c}->user;
    my %bodies = map { $_->body->name => $_->body } @$contacts;
    my $b = $bodies{'Isle of Wight Council'};

    if ( $user && ( $user->is_superuser || $user->belongs_to_body( $b->id ) ) ) {
        @$contacts = grep { !$_->send_method || $_->send_method ne 'Triage' } @$contacts;
        my $seen = { map { $_->category => 1 } @$contacts };
        @$options = grep { my $c = ($_->{category} || $_->category); $c =~ 'Pick a category' || $seen->{ $c } } @$options;
        return;
    }

    @$contacts = grep { $_->send_method && $_->send_method eq 'Triage' } @$contacts;
    my $seen = { map { $_->category => 1 } @$contacts };
    @$options = grep { my $c = ($_->{category} || $_->category); $c =~ 'Pick a category' || $seen->{ $c } } @$options;
}

sub munge_category_where {
    my ($self, $where) = @_;

    my $user = $self->{c}->user;
    my $b = $self->{c}->model('DB::Body')->for_areas( $self->council_area_id )->first;
    if ( $user && ( $user->is_superuser || $user->belongs_to_body( $b->id ) ) ) {
        $where = {
            body_id => $where->{body_id},
            send_method => [ { '!=' => 'Triage' }, undef ],
        };
        return $where;
    }

    $where->{'send_method'} = 'Triage';
    return $where;
}

sub munge_load_and_group_problems {
    my ($self, $where, $filter) = @_;

    return unless $where->{category};

    my $cat_names = $self->expand_triage_cat_list($where->{category});

    $where->{category} = $cat_names;
    my $problems = $self->problems->search($where, $filter);
    return $problems;
}

sub munge_filter_category {
    my $self = shift;

    my $c = $self->{c};
    return unless $c->stash->{filter_category};

    my $cat_names = $self->expand_triage_cat_list([ keys %{$c->stash->{filter_category}} ]);
    $c->stash->{filter_category} = { map { $_ => 1 } @$cat_names };
}

# this assumes that each Triage category has the same name as a group
# and uses this to generate a list of categories that a triage category
# could be triaged to
sub expand_triage_cat_list {
    my ($self, $categories) = @_;

    my $b = $self->{c}->model('DB::Body')->for_areas( $self->council_area_id )->first;

    my $all_cats = $self->{c}->model('DB::Contact')->not_deleted->search(
        {
            body_id => $b->id,
            send_method => [{ '!=', 'Triage'}, undef]
        }
    );

    my %group_to_category;
    while ( my $cat = $all_cats->next ) {
        next unless $cat->get_extra_metadata('group');
        my $groups = $cat->get_extra_metadata('group');
        $groups = ref $groups eq 'ARRAY' ? $groups : [ $groups ];
        for my $group ( @$groups ) {
            $group_to_category{$group} //= [];
            push @{ $group_to_category{$group} }, $cat->category;
        }
    }

    my $cats = $self->{c}->model('DB::Contact')->not_deleted->search(
        {
            body_id => $b->id,
            category => $categories
        }
    );

    my @cat_names;
    while ( my $cat = $cats->next ) {
        if ( $cat->send_method eq 'Triage' ) {
            # include the category itself
            push @cat_names, $cat->category;
            push @cat_names, @{ $group_to_category{$cat->category} } if $group_to_category{$cat->category};
        } else {
            push @cat_names, $cat->category;
        }
    }

    return \@cat_names;
}

sub open311_get_update_munging {
    my ($self, $comment) = @_;

    # If we've received an update via Open311 that's closed
    # or fixed the report, also close it to updates.
    $comment->problem->set_extra_metadata(closed_updates => 1)
        if !$comment->problem->is_open;
}

sub admin_pages {
    my $self = shift;
    my $pages = $self->next::method();
    $pages->{triage} = [ undef, undef ];
    return $pages;
}

sub available_permissions {
    my $self = shift;

    my $perms = $self->next::method();
    $perms->{Problems}->{triage} = "Triage reports";

    return $perms;
}
1;
