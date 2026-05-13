package FixMyStreet::Script::UpdateCouncilUsersWithoutRole;

use v5.14;
use warnings;

use FixMyStreet::DB;

sub update {
    my $opts = shift;

    if (!$opts->{commit}) {
        say "*** DRY RUN ***";
    }

    my $users = FixMyStreet::DB->resultset("User")->search({
        from_body => { "!=", undef },
        id => {
            -not_in => FixMyStreet::DB->resultset("UserRole")->search(
                undef,
                {
                    columns => ['user_id']
                }
            )->as_query
        }
    });

    if ( $opts->{council} ) {
        my $body = FixMyStreet::DB->resultset("Body")->find({ name => $opts->{council}});
        if ($body) {
            $users = $users->search({
                from_body => $body->id
            });
        } else {
            die "Could not find " . $opts->{council};
        }
    }

    if ($opts->{with_permission}) {
        my $permission = Utils::trim_text($opts->{with_permission});
				$users = $users->search(
					id => {
						-in => FixMyStreet::DB->resultset('UserBodyPermission')->search(
              {
                permission_type => { in => [$permission]}
							},
              {
                  columns => ['user_id']
              }
            )->as_query
        });
    }

    if ($users->count) {
        my @permissions_list = map { Utils::trim_text($_) } split(',', $opts->{permissions});

        for my $user ( $users->all ) {
            my $permissions = $user->user_body_permissions->search({
                body_id => $user->from_body->id,
                permission_type => { in => \@permissions_list}
            });
            if ( $opts->{mode} eq 'remove') {
                next unless $permissions->count;
                if ($opts->{commit}) {
                    $permissions->delete;
                }
            } elsif ( $opts->{mode} eq 'add' ) {
                my %existing = map { $_->permission_type => 1 } $permissions->all;
                my @permissions_to_add = grep { !$existing{$_} } @permissions_list;
                next unless @permissions_to_add;
                if ($opts->{commit}) {
                    for my $permission ( @permissions_to_add ) {
                        $user->user_body_permissions->create({
                            body_id => $user->from_body->id,
                            permission_type => $permission
                        });
                    }
                }
            }
            say "updated permissions for user id " . $user->id . " from " . $user->from_body->name unless $opts->{verbose};
        }
    }

}

1;
