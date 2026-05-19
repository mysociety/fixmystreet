package FixMyStreet::Script::UpdateRoles;

use v5.14;
use warnings;

use FixMyStreet::DB;

sub update {
    my $opts = shift;

    if (!$opts->{commit}) {
        say "*** DRY RUN ***";
    }

    my $body = FixMyStreet::DB->resultset("Body")->find({ name => $opts->{council}});

    if ($opts->{council} && !$body) {
        die "Could not find a body matching " . $opts->{council} . "\n";
    }

    my $roles;
    if ($body) {
        $roles = FixMyStreet::DB->resultset("Role")->search({ body_id => $body->id });
    } else {
        $roles = FixMyStreet::DB->resultset("Role");
    }

    if ($opts->{with_permission}) {
        my $permission = Utils::trim_text($opts->{with_permission});
        $roles = $roles->search({
            permissions => \"@> ARRAY['$permission']"
        });
    }
    my %permissions_list = map { Utils::trim_text($_) => 1 } split(',', $opts->{permissions});

    for my $role ( $roles->all ) {
        my $permissions = $role->permissions;
		my $new_permissions;

        if ( $opts->{mode} eq 'remove') {
            next unless $permissions;
            $new_permissions = [ grep { !$permissions_list{$_} } @$permissions ];
        } elsif ( $opts->{mode} eq 'add' ) {
            my %existing = map { $_ => 1 } @$permissions;
            my @permissions_to_add = grep { !$existing{$_} } keys %permissions_list;
            next unless @permissions_to_add;
            $new_permissions = [@$permissions, @permissions_to_add];
        }
        if ($opts->{commit}) {
            $role->permissions($new_permissions);
            $role->update;
        }
        say "updated permissions for role id " . $role->id . " to " . join ",", @$new_permissions if $opts->{verbose};

    }
}

1;
