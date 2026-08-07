package FixMyStreet::Script::ExportImport;

use Moo;
use FixMyStreet::DB;
use JSON::MaybeXS;
use Path::Tiny;

has commit => ( is => 'ro' );

has body => ( is => 'ro', coerce => sub {
    my $name = shift;
    my $body = FixMyStreet::DB->resultset("Body")->find({ name => $name })
        or die "Cannot find body $name\n";
    return $body;
});

my $J = JSON::MaybeXS->new(utf8 => 1, pretty => 1, canonical => 1);

sub export_json {
    my ($self, $categories, $all_categories) = @_;
    my $body = $self->body;
    my %out;

    if (@$categories || $all_categories) {
        my @contacts = $body->contacts->search({
            $all_categories ? () : ( category => { -in => $categories } ),
        }, {
            order_by => 'category',
        })->all;
        die "Categories mismatch\n" unless (scalar @$categories == scalar @contacts) || $all_categories;
        for (@contacts) {
            push @{$out{contacts}}, {
                category => $_->category,
                email => $_->email,
                state => $_->state,
                send_method => $_->send_method || '',
                non_public => $_->non_public ? JSON->true : JSON->false,
                extra => $_->extra,
            };
        }
    }

    my $templates = $body->response_templates->order_by('title');
    if (@$categories) {
        $templates = $templates->search({
            'contact.category' => { -in => \@$categories }
        }, {
            join => { 'contact_response_templates' => 'contact' }
        });
    }
    for ($templates->all) {
        push @{$out{templates}}, {
            title => $_->title,
            text => $_->text,
            email_text => $_->email_text,
            state => $_->state,
            categories => [ sort map { $_->category } $_->contacts->all ],
            auto_response => $_->auto_response,
            external_status_code => $_->external_status_code,
        };
    }

    for ($body->roles->order_by('name')->all) {
        push @{$out{roles}}, {
            permissions => $_->permissions,
            name => $_->name,
        };
    }

    for ($body->users->order_by('name')->all) {
        my $cats = $_->get_extra_metadata('categories');
        my @cat_names = sort map { $body->contacts->find({id => $_})->category } @$cats;
        push @{$out{users}}, {
            email => $_->email,
            name => $_->name,
            password => $_->password,
            roles => [ sort map { $_->name } $_->roles->all ],
            categories => \@cat_names,
            areas => $_->area_ids || [],
        };
    }

    return $J->encode(\%out);
}

sub import_json {
    my ($self, $file, $update_templates, $update_contacts) = @_;
    my $body = $self->body;

    my $json = path($file)->slurp;
    my $out = $J->decode($json);

    my $db = FixMyStreet::DB->schema->storage;
    $db->txn_begin;

    foreach (@{$out->{contacts}}) {
        my $existing = $body->contacts->search({ category => $_->{category} })->single;
        if ($existing) {
            if ($update_contacts) {
                $existing->update({
                    note => "Updated from $file",
                    editor => 'export-import-data',
                    whenedited => \'current_timestamp',
                    email => $_->{email},
                    state => $_->{state},
                    send_method => $_->{send_method},
                    non_public => $_->{non_public},
                    extra => $_->{extra},
                });
            } else {
                warn "Category $_->{category} already exists, skipping\n";
                next;
            }
        } else {
            my $contact = $body->contacts->new({
                note => "Imported from $file",
                editor => 'export-import-data',
                whenedited => \'current_timestamp',
                category => $_->{category},
                email => $_->{email},
                state => $_->{state},
                non_public => $_->{non_public},
                extra => $_->{extra},
            });
            $contact->insert;
        }
    }

    foreach (@{$out->{templates}}) {
        my $existing = $body->response_templates->search({ title => $_->{title} })->single;
        if ($existing && !$update_templates) {
            warn "Template with title $_->{title} already exists, skipping\n";
            next;
        }
        my $template = $body->response_templates->update_or_new({
            title => $_->{title},
            text => $_->{text},
            email_text => $_->{email_text},
            state => $_->{state},
            auto_response => $_->{auto_response},
            external_status_code => $_->{external_status_code},
        });
        $template->insert unless $template->in_storage;
        foreach (@{$_->{categories}}) {
            my $contact = $body->contacts->find({ category => $_ });
            unless ( $contact ) {
                my $msg = "Cannot find category $_ for template " . $template->title . "\n";
                if ($update_templates) {
                    warn $msg;
                    next;
                } else {
                    die $msg;
                }
            }
            $template->contact_response_templates->find_or_create({
                contact_id => $contact->id,
            });
        }
    }

    for my $r (@{$out->{roles}}) {
        my $role = $body->roles->find_or_new({
            name => $r->{name},
            permissions => $r->{permissions},
        });
        if ($role->in_storage) {
            warn "Role $r->{name} already exists; skipping\n";
            next;
        }
        $role->insert;
    }

    for my $u (@{$out->{users}}) {
        my $user = FixMyStreet::DB->resultset("User")->find_or_new({ email => $u->{email}, email_verified => 1 });
        if ($user->in_storage) {
            warn "User $u->{email} already exists; skipping\n";
            next;
        }
        $user->from_body($body->id);
        $user->name($u->{name});
        $user->password($u->{password}, 1);
        $user->area_ids($u->{areas});

        $user->insert;

        foreach my $role (@{$u->{roles}}) {
            my $role = $body->roles->find({ name => $role }) or die "Couldn't find role $role for user $u->{email}\n";
            $user->user_roles->create({
                role_id => $role->id,
            });
        }

        my @cat_ids;
        for my $cat_name (@{$u->{categories}}) {
            my $cat = $body->contacts->find({ category => $cat_name }) or die "Couldn't find category $cat_name for user $u->{email}\n";
            push @cat_ids, $cat->id;
        }
        $user->set_extra_metadata('categories', \@cat_ids);
        $user->set_extra_metadata(last_password_change => time());
        $user->update;
    }

    if ($self->commit) {
        $db->txn_commit;
    } else {
        $db->txn_rollback;
    }
}

1;
