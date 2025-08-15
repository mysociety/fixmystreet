package FixMyStreet::App::Controller::Admin::Bodies;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use POSIX qw(strcoll);
use JSON::MaybeXS;
use List::MoreUtils qw(uniq);
use mySociety::EmailUtil qw(is_valid_email_list);
use FixMyStreet::MapIt;
use FixMyStreet::SendReport;
use FixMyStreet::Cobrand;

=head1 NAME

FixMyStreet::App::Controller::Admin::Bodies - Catalyst Controller

=head1 DESCRIPTION

Admin pages

=head1 METHODS

=head2 index

This shows a list of bodies to superusers, or redirects to a body's category list page if not.

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    if (my $body_id = $c->get_param('body')) {
        return $c->res->redirect( $c->uri_for_action('admin/bodies/edit', [ $body_id ] ) );
    }

    if (!$c->user->is_superuser && $c->user->from_body && $c->cobrand->moniker ne 'zurich') {
        return $c->res->redirect( $c->uri_for_action('admin/bodies/edit', [ $c->user->from_body->id ] ) );
    }

    my $edit_activity = $c->model('DB::ContactsHistory')->search(
        undef,
        {
            select => [ 'editor', { count => 'contacts_history_id', -as => 'c' } ],
            as     => [ 'editor', 'c' ],
            group_by => ['editor'],
            order_by => { -desc => 'c' }
        }
    );

    $c->stash->{edit_activity} = $edit_activity;

    $c->forward( '/admin/fetch_all_bodies' );

    my $contacts = $c->model('DB::Contact')->search(
        undef,
        {
            select => [ 'body_id', { count => 'id' }, { count => \'case when state = \'deleted\' then 1 else null end' },
            { count => \'case when state = \'confirmed\' then 1 else null end' } ],
            as => [qw/body_id c deleted confirmed/],
            group_by => [ 'body_id' ],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator'
        }
    );

    my %council_info = map { $_->{body_id} => $_ } $contacts->all;
    $c->stash->{counts} = \%council_info;
}

=head2 body

Captures the body ID from the URL and fetches that body from the database.

=cut

sub body : Chained('/') : PathPart('admin/body') : CaptureArgs(1) {
    my ( $self, $c, $body_id ) = @_;

    $c->stash->{body_id} = $body_id;
    my $body = $c->model('DB::Body')->find($body_id);
    $c->detach( '/page_error_404_not_found', [] ) unless $body;
    $c->stash->{body} = $body;

    if ($body->body_areas->first) {
        my $example_postcode = FixMyStreet::MapIt::call('area/example_postcode', $body->body_areas->first->area_id);
        if ($example_postcode && ! ref $example_postcode) {
            $c->stash->{example_pc} = $example_postcode;
        }
    }
}

=head2 add

Controller for adding a new body.

=cut

sub add : Path('add') : Args(0) {
    my ($self, $c) = @_;

    $c->forward('check_for_super_user');
    $c->forward('/auth/get_csrf_token');
    $c->forward('/admin/fetch_all_bodies');
    $c->forward('body_form_dropdowns');
    $c->forward('/admin/fetch_languages');
    $c->forward('fetch_translations');

    if ($c->req->method eq 'POST') {
        $c->forward('update_body', [ undef, _('New body added') ]);
    }
}

=head2 edit

Controller for showing a list of categories for a body, and editing that body.

=cut

sub edit : Chained('body') : PathPart('') : Args(0) {
    my ( $self, $c ) = @_;

    unless ($c->user->has_permission_to('category_edit', $c->stash->{body_id})) {
        $c->forward('check_for_super_user');
    }

    $c->forward( '/auth/get_csrf_token' );
    $c->forward( '/admin/fetch_all_bodies' );
    $c->forward( 'body_form_dropdowns' );
    $c->forward('/admin/fetch_languages');

    $c->stash->{object} = $c->stash->{body};
    $c->stash->{translation_col} = 'name';
    $c->forward('fetch_translations');

    if ($c->req->method eq 'POST') {
        $c->forward('update_body', [ $c->stash->{body}, _('Values updated') ]);
    }

    # don't set this last as fetch_contacts might over-ride it
    # to display email addresses as text
    $c->stash->{template} = 'admin/bodies/body.html';
    $c->forward('/admin/fetch_contacts');
    $c->stash->{contacts} = [ $c->stash->{contacts}->all ];
    $c->forward('/report/stash_category_groups', [ $c->stash->{contacts} ]);

    if ( defined $c->flash->{status_message} ) {
        $c->stash->{updated} = $c->flash->{status_message};
    }

    return 1;
}

=head2 attributes

Controller for managing hierarchical attributes (Zurich only).

=cut

sub attributes : Chained('body') : PathPart('attributes') : Args(0) {
    my ($self, $c) = @_;

    # Only for Zurich cobrand
    unless ($c->cobrand->moniker eq 'zurich') {
        $c->detach('/page_error_404_not_found', []);
    }

    unless ($c->user->has_permission_to('category_edit', $c->stash->{body_id})) {
        $c->forward('check_for_super_user');
    }

    $c->forward('/auth/get_csrf_token');

    my $body = $c->stash->{body};
    my $attributes = $body->get_extra_metadata('hierarchical_attributes') || {};

    # Initialize with defaults if empty
    if (!keys %$attributes) {
        $attributes = $c->cobrand->get_default_hierarchical_attributes();
    }

    if ($c->req->method eq 'POST') {
        $c->forward('/auth/check_csrf_token');
        $c->forward('update_hierarchical_attributes', [$body, $attributes]);
    }

    $c->stash->{hierarchical_attributes} = $attributes;
    $c->stash->{template} = 'admin/bodies/attributes.html';

    if (defined $c->flash->{status_message}) {
        $c->stash->{updated} = $c->flash->{status_message};
    }

    return 1;
}

=head2 add_category

Controller for adding a new category.

=cut

sub add_category : Chained('body') : PathPart('_add') : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{template} = 'admin/bodies/category.html';
    $c->forward('category');
}

=head2 category

Controller for showing/editing a new category.

=cut

sub category : Chained('body') : PathPart('') {
    my ( $self, $c, @category ) = @_;
    my $category = join( '/', @category );

    $c->forward( '/auth/get_csrf_token' );

    if ($category) {
        my $contact = $c->stash->{body}->contacts->search( { category => $category } )->first;
        $c->detach( '/page_error_404_not_found', [] ) unless $contact;
        $c->stash->{contact} = $c->stash->{current_contact} = $contact;
        $c->stash->{object} = $c->stash->{contact};
    }

    $c->stash->{translation_col} = 'category';

    $c->forward('/admin/fetch_languages');
    $c->forward('fetch_translations');

    if ($c->req->method eq 'POST') {
        $c->forward('update_contact');
    }

    if ($category) {
        my $history = $c->model('DB::ContactsHistory')->search(
            {
                contact_id => $c->stash->{contact}->id,
            },
            {
                rows => 998, # Limit of WHILE in template
            },
        )->order_by('-contacts_history_id')->as_subselect_rs->order_by('contacts_history_id');
        $c->stash->{history} = $history;
    }

    my @methods = map { $_ =~ s/FixMyStreet::SendReport:://; $_ } sort keys %{ FixMyStreet::SendReport->get_senders };
    $c->stash->{send_methods} = \@methods;

    if ( defined $c->flash->{status_message} ) {
        $c->stash->{updated} = $c->flash->{status_message};
    }

    return 1;
}

sub body_form_dropdowns : Private {
    my ( $self, $c ) = @_;

    my $areas;
    my $whitelist = $c->config->{MAPIT_ID_WHITELIST};

    if ( $whitelist && ref $whitelist eq 'ARRAY' && @$whitelist ) {
        $areas = FixMyStreet::MapIt::call('areas', $whitelist);
    } else {
        $areas = FixMyStreet::MapIt::call('areas', $c->cobrand->area_types_for_admin);
    }

    # Some cobrands may want to add extra areas at runtime beyond those
    # available via MAPIT_WHITELIST or MAPIT_TYPES. This can be used for,
    # e.g., parish councils on a particular council cobrand.
    $areas = $c->cobrand->call_hook("add_extra_areas_for_admin" => $areas) || $areas;

    $c->stash->{areas} = [ sort { strcoll($a->{name}, $b->{name}) } values %$areas ];

    my @methods = map { $_ =~ s/FixMyStreet::SendReport:://; $_ } sort keys %{ FixMyStreet::SendReport->get_senders };
    $c->stash->{send_methods} = \@methods;

    my @cobrands = uniq sort map { $_->{moniker} } FixMyStreet::Cobrand->available_cobrand_classes;
    $c->stash->{cobrands} = \@cobrands;
}

sub check_for_super_user : Private {
    my ( $self, $c ) = @_;

    my $superuser = $c->user->is_superuser;
    # Zurich currently has its own way of defining superusers
    $superuser ||= $c->cobrand->moniker eq 'zurich' && $c->stash->{admin_type} eq 'super';

    unless ( $superuser ) {
        $c->detach('/page_error_403_access_denied', []);
    }
}

sub update_contact : Private {
    my ( $self, $c ) = @_;

    my $editor = $c->forward('/admin/get_user');
    $c->forward('/auth/check_csrf_token');

    my %errors;

    my $current_category = $c->get_param('current_category') || '';
    my $current_contact = $c->model('DB::Contact')->find({
        body_id => $c->stash->{body_id},
        category => $current_category,
    });
    $c->stash->{current_contact} = $current_contact;

    my $category = $self->trim( $c->get_param('category') );
    $errors{category} = _("Please choose a category") unless $category;

    my $body = $c->model('DB::Body')->find({
        id => $c->stash->{body_id},
    });
    my $cobrand = $body->get_cobrand_handler;
    my $category_validation_error = $cobrand ? $cobrand->call_hook(admin_contact_validate_category => $category) : "";
    $errors{category} = $category_validation_error if $category_validation_error;

    $errors{note} = _('Please enter a message') unless $c->get_param('note') || FixMyStreet->config('STAGING_SITE');

    my $contact = $c->model('DB::Contact')->find_or_new(
        {
            body_id => $c->stash->{body_id},
            category => $category,
        }
    );
    if ($current_contact && $contact->id && $contact->id != $current_contact->id) {
        $errors{category} = _('You cannot rename a category to an existing category');
    } elsif ($current_contact && !$contact->id) {
        $contact = $current_contact;
        # Set the flag here so we can run the editable test on it
        $contact->set_extra_metadata(open311_protect => $c->get_param('open311_protect'));
        if (!$contact->category_uneditable) {
            # Changed name
            $c->model('DB::Problem')->to_body($c->stash->{body_id})->search({ category => $current_category })->update({ category => $category });
            $contact->category($category);
        }
    }

    my $email = $c->get_param('email');
    my $send_method = $c->get_param('send_method') || $contact->body->send_method || "";
    if ($send_method eq 'Open311') {
        $email =~ s/^\s+|\s+$//g;
    } else {
        $email =~ s/\s+//g;
    }
    my $email_unchanged = $contact->email && $email && $contact->email eq $email;
    my $cobrand_valid = $cobrand && $cobrand->call_hook(validate_contact_email => $email);
    unless ( $send_method eq 'Open311' || $email_unchanged || $cobrand_valid ) {
        $errors{email} = _('Please enter a valid email') unless is_valid_email_list($email) || $email eq 'REFUSED';
    }

    $contact->email( $email );
    $contact->state( $c->get_param('state') );
    $contact->non_public( $c->get_param('non_public') ? 1 : 0 );
    $contact->note( $c->get_param('note') );
    $contact->whenedited( \'current_timestamp' );
    $contact->editor( $editor );
    $contact->endpoint( $c->get_param('endpoint') );
    $contact->jurisdiction( $c->get_param('jurisdiction') );
    $contact->api_key( $c->get_param('api_key') );
    $contact->send_method( $c->get_param('send_method') );

    # Set flags in extra to the appropriate values
    foreach (qw(photo_required open311_protect updates_disallowed reopening_disallowed assigned_users_only anonymous_allowed prefer_if_multiple phone_required litter_category_for_he)) {
        if ( $c->get_param($_) ) {
            $contact->set_extra_metadata( $_ => 1 );
        } else {
            $contact->unset_extra_metadata($_);
        }
    }

    if (my $type = $c->get_param('type')) {
        if ($type eq 'standard') {
            $contact->unset_extra_metadata('type');
        } else {
            $contact->set_extra_metadata(type => $type);
        }
    }

    foreach (qw(title_hint detail_label detail_hint)) {
        my $value = $c->get_param($_) || '';
        $value = $self->trim($value);
        if ($value) {
            $contact->set_extra_metadata( $_ => $value );
        } else {
            $contact->unset_extra_metadata($_);
        }
    }

    if ( $c->user->is_superuser ) {
        if ( $c->get_param('hardcoded') ) {
            $contact->set_extra_metadata( hardcoded => 1 );
        } else {
            $contact->unset_extra_metadata('hardcoded');
        }
    }

    if ( my @group = $c->get_param_list('group') ) {
        @group = grep { $_ } @group;
        if (scalar @group == 0) {
            $contact->unset_extra_metadata( 'group' );
        } else {
            $contact->set_extra_metadata( group => \@group );
        }
    } else {
        $contact->unset_extra_metadata( 'group' );
    }

    $c->forward('/admin/update_extra_fields', [ $contact ]);
    $c->forward('contact_cobrand_extra_fields', [ $contact, \%errors ]);

    for ( @{ $contact->extra->{_fields} } ) {
        if ( $_->{code} =~ /\s/ ) {
            $errors{code} = _('Codes for extra data must not contain spaces');
            last;
        }
    }

    # Special form disabling form
    if ($c->get_param('disable')) {
        my $msg = $c->get_param('disable_message');
        $msg = FixMyStreet::Template::sanitize($msg, 1);
        $errors{category} = _('Please enter a message') unless $msg;
        my $meta = {
            code => '_fms_disable_',
            variable => 'false',
            protected => 'true',
            disable_form => 'true',
            description => $msg,
        };
        $contact->update_extra_field($meta);
    } else {
        $contact->remove_extra_field('_fms_disable_');
    }

    if ( %errors ) {
        $c->stash->{updated} = _('Please correct the errors below');
        $c->stash->{contact} = $contact;
        $c->stash->{errors} = \%errors;
    } elsif ( $contact->in_storage ) {
        $c->flash->{status_message} = _('Values updated');
        $c->forward('/admin/log_edit', [ $contact->id, 'category', 'edit' ]);
        # NB: History is automatically stored by a trigger in the database
        $contact->update;
    } else {
        $c->flash->{status_message} = _('New category contact added');
        $contact->insert;
        $c->forward('/admin/log_edit', [ $contact->id, 'category', 'add' ]);
    }

    unless ( %errors ) {
        $c->stash->{translation_col} = 'category';
        $c->stash->{object} = $contact;
        $c->forward('update_translations');
        $c->res->redirect($c->uri_for_action('/admin/bodies/edit', [ $contact->body_id ]));
    }
}

sub confirm_contacts : Chained('body') : PathPart('_confirm') : Args(0) {
    my ( $self, $c ) = @_;

    my $body_id = $c->stash->{body_id};
    unless ($c->user->has_permission_to('category_edit', $body_id)) {
        $c->forward('check_for_super_user');
    }

    unless ($c->req->method eq 'POST') {
        $c->res->redirect($c->uri_for_action('/admin/bodies/edit', [ $body_id ]));
        $c->detach;
    }

    $c->forward('/auth/check_csrf_token');

    my @categories = $c->get_param_list('confirmed');

    my $contacts = $c->model('DB::Contact')->search(
        {
            body_id => $body_id,
            category => { -in => \@categories },
        }
    );

    my $editor = $c->forward('/admin/get_user');
    $contacts->update(
        {
            state => 'confirmed',
            whenedited => \'current_timestamp',
            note => 'Confirmed',
            editor => $editor,
        }
    );

    $c->forward('/admin/log_edit', [ $body_id, 'body', 'edit' ]);
    $c->flash->{status_message} = _('Values updated');
    $c->res->redirect($c->uri_for_action('/admin/bodies/edit', [ $body_id ]));
}

sub update_body : Private {
    my ($self, $c, $body, $msg) = @_;

    $c->forward('check_for_super_user');
    $c->forward('/auth/check_csrf_token');

    my $values = $c->forward('body_params');
    return if %{$c->stash->{body_errors}};

    if ($body) {
        $body->update( $values->{params} );
        $c->forward('/admin/log_edit', [ $body->id, 'body', 'edit' ]);
    } else {
        $body = $c->model('DB::Body')->create( $values->{params} );
        $c->forward('/admin/log_edit', [ $body->id, 'body', 'add' ]);
    }

    if ($values->{extras}) {
        $body->set_extra_metadata( $_ => $values->{extras}->{$_} )
            for keys %{$values->{extras}};
        $body->update;
    }

    my %possible = map { $_->{id} => 1 } @{$c->stash->{areas}};
    my @current = $body->body_areas->all;
    # Don't want to remove any that weren't present in the list
    @current = grep { $possible{$_->area_id} } @current;
    my %current = map { $_->area_id => 1 } @current;
    my @area_ids = $c->get_param_list('area_ids');
    foreach (@area_ids) {
        $c->model('DB::BodyArea')->find_or_create( { body => $body, area_id => $_ } );
        delete $current{$_};
    }
    # Remove any others
    $body->body_areas->search( { area_id => [ keys %current ] } )->delete;

    $c->stash->{translation_col} = 'name';
    $c->stash->{object} = $body;
    $c->forward('update_translations');

    $c->flash->{status_message} = $msg;
    $c->res->redirect($c->uri_for_action('/admin/bodies/edit', [ $body->id ]));
}

sub body_params : Private {
    my ( $self, $c ) = @_;

    my @fields = qw/name endpoint jurisdiction api_key send_method external_url/;
    my %defaults = map { $_ => '' } @fields;
    %defaults = ( %defaults,
        send_comments => 0,
        fetch_problems => 0,
        convert_latlong => 0,
        blank_updates_permitted => 0,
        suppress_alerts => 0,
        comment_user_id => undef,
        send_extended_statuses => 0,
        can_be_devolved => 0,
        parent => undef,
        deleted => 0,
        cobrand => undef,
    );
    my %params = map { $_ => $c->get_param($_) || $defaults{$_} } keys %defaults;
    $c->forward('check_body_params', [ \%params ]);

    my @extras = qw/fetch_all_problems/;
    my $cobrand_extras = $c->cobrand->call_hook('body_extra_fields');
    push @extras, @$cobrand_extras if $cobrand_extras;

    %defaults = map { $_ => '' } @extras;
    my %extras = map { $_ => $c->get_param("extra[$_]") || $defaults{$_} } @extras;
    $c->forward('check_body_extras', [ \%extras ]);
    return { params => \%params, extras => \%extras };
}

sub check_body_params : Private {
    my ( $self, $c, $params ) = @_;

    $c->stash->{body_errors} ||= {};

    unless ($params->{name}) {
        $c->stash->{body_errors}->{name} = _('Please enter a name for this body');
    }

    if ($params->{cobrand}) {
        if (my $b = $c->model('DB::Body')->find({
            id => { '!=', $c->stash->{body_id} },
            cobrand => $params->{cobrand},
        })) {
            $c->stash->{body_errors}->{cobrand} = _('This cobrand is already assigned to another body: ' . $b->name);
        }
    }
}

sub check_body_extras : Private {
    my ( $self, $c, $extras ) = @_;

    $c->stash->{body_errors} ||= {};
}

sub contact_cobrand_extra_fields : Private {
    my ( $self, $c, $contact, $errors ) = @_;

    my $extra_fields = $c->cobrand->call_hook('contact_extra_fields');
    foreach ( @$extra_fields ) {
        $contact->set_extra_metadata( $_ => $c->get_param("extra[$_]") );
    }
    $c->cobrand->call_hook(contact_extra_fields_validation => $contact, $errors);
}

sub fetch_translations : Private {
    my ( $self, $c ) = @_;

    my $translations = {};
    if ($c->req->method eq 'POST') {
        foreach my $lang (keys %{$c->stash->{languages}}) {
            if (my $msgstr = $c->get_param('translation_' . $lang)) {
                $translations->{$lang} = { msgstr => $msgstr };
            }
            if (my $id = $c->get_param('translation_id_' . $lang)) {
                $translations->{$lang}->{id} = $id;
            }
        }
    } elsif ($c->stash->{object}) {
        my @translations = $c->stash->{object}->translation_for($c->stash->{translation_col})->all;

        foreach my $tx (@translations) {
            $translations->{$tx->lang} = { id => $tx->id, msgstr => $tx->msgstr };
        }
    }

    $c->stash->{translations} = $translations;
}

sub update_translations : Private {
    my ( $self, $c ) = @_;

    foreach my $lang (keys(%{$c->stash->{languages}})) {
        my $id = $c->get_param('translation_id_' . $lang);
        my $text = $c->get_param('translation_' . $lang);
        if ($id) {
            my $translation = $c->model('DB::Translation')->find(
                {
                    id => $id,
                }
            );

            if ($text) {
                $translation->msgstr($text);
                $translation->update;
            } else {
                $translation->delete;
            }
        } elsif ($text) {
            my $col = $c->stash->{translation_col};
            $c->stash->{object}->add_translation_for(
                $col, $lang, $text
            );
        }
    }
}

sub update_hierarchical_attributes : Private {
    my ($self, $c, $body, $attributes) = @_;

    my %errors;
    my $updated = 0;

    foreach my $level_name (keys %$attributes) {
        my $level = $attributes->{$level_name};
        my $name_param = "new_${level_name}_name";
        my $parent_param = "new_${level_name}_parent";

        if (my $new_name = $c->get_param($name_param)) {
            $new_name = $self->trim($new_name);
            if ($new_name) {
                if (length($new_name) < 1) {
                    $errors{$name_param} = _('Name cannot be empty');
                    next;
                } elsif (length($new_name) > 255) {
                    $errors{$name_param} = _('Name is too long (maximum 255 characters)');
                    next;
                }

                my $duplicate = 0;
                foreach my $existing_id (keys %{$level->{entries}}) {
                    my $existing_entry = $level->{entries}->{$existing_id};
                    if (!$existing_entry->{deleted} && lc($existing_entry->{name}) eq lc($new_name)) {
                        $errors{$name_param} = _('An entry with this name already exists');
                        $duplicate = 1;
                        last;
                    }
                }
                next if $duplicate;

                my $max_id = 0;
                for my $id (keys %{$level->{entries}}) {
                    $max_id = $id if $id > $max_id;
                }
                my $new_id = $max_id + 1;

                my $new_entry = {
                    name => $new_name,
                    deleted => 0,
                };

                if ($level->{parent}) {
                    my $parent_id = $c->get_param($parent_param);
                    if (!$parent_id) {
                        $errors{$parent_param} = _('Parent is required');
                        next;
                    }

                    my $parent_level = $attributes->{$level->{parent}};
                    my $parent_entry = $parent_level->{entries}->{$parent_id};
                    if (!$parent_entry || $parent_entry->{deleted}) {
                        $errors{$parent_param} = _('Invalid parent selected');
                        next;
                    }

                    $new_entry->{parent_id} = int($parent_id);
                }

                $level->{entries}->{$new_id} = $new_entry;
                $updated = 1;
            }
        }

        foreach my $id (keys %{$level->{entries}}) {
            my $entry = $level->{entries}->{$id};
            my $name_param = "${level_name}_${id}_name";
            my $parent_param = "${level_name}_${id}_parent";
            my $deleted_param = "${level_name}_${id}_deleted";

            if (defined(my $name = $c->get_param($name_param))) {
                $name = $self->trim($name);
                if (length($name) < 1) {
                    $errors{$name_param} = _('Name cannot be empty');
                    next;
                } elsif (length($name) > 255) {
                    $errors{$name_param} = _('Name is too long (maximum 255 characters)');
                    next;
                } elsif ($name ne $entry->{name}) {
                    # Check for duplicates excluding current entry
                    my $duplicate = 0;
                    foreach my $other_id (keys %{$level->{entries}}) {
                        next if $other_id eq $id;
                        my $other_entry = $level->{entries}->{$other_id};
                        if (!$other_entry->{deleted} && lc($other_entry->{name}) eq lc($name)) {
                            $errors{$name_param} = _('An entry with this name already exists');
                            $duplicate = 1;
                            last;
                        }
                    }
                    next if $duplicate;

                    $entry->{name} = $name;
                    $updated = 1;
                }
            }

            my $deleted = $c->get_param($deleted_param) ? 1 : 0;
            if ($deleted != $entry->{deleted}) {
                # Prevent deletion if entry has active children
                if ($deleted) {
                    my $has_children = 0;
                    foreach my $other_level_name (keys %$attributes) {
                        my $other_level = $attributes->{$other_level_name};
                        if ($other_level->{parent} && $other_level->{parent} eq $level_name) {
                            foreach my $child_entry (values %{$other_level->{entries}}) {
                                if (!$child_entry->{deleted} && ($child_entry->{parent_id} || 0) == $id) {
                                    $has_children = 1;
                                    last;
                                }
                            }
                            last if $has_children;
                        }
                    }
                    if ($has_children) {
                        $errors{$deleted_param} = _('Cannot delete entry that has active child entries');
                        next;
                    }
                }

                $entry->{deleted} = $deleted;
                $updated = 1;
            }

            if ($level->{parent}) {
                my $parent_id = $c->get_param($parent_param);
                if ($parent_id && $self->trim($parent_id)) {
                    $parent_id = int($parent_id);
                    if (($entry->{parent_id} || 0) != $parent_id) {
                        if ($parent_id > 0) {
                            my $parent_level = $attributes->{$level->{parent}};
                            my $parent_entry = $parent_level->{entries}->{$parent_id};
                            if (!$parent_entry || $parent_entry->{deleted}) {
                                $errors{$parent_param} = _('Invalid parent selected');
                                next;
                            }
                        }

                        $entry->{parent_id} = $parent_id;
                        $updated = 1;
                    }
                }
            }
        }
    }

    if (%errors) {
        $c->stash->{errors} = \%errors;
        $c->stash->{updated} = _('Please correct the errors below');
    } elsif ($updated) {
        $body->set_extra_metadata('hierarchical_attributes', $attributes);
        $body->update;
        $c->forward('/admin/log_edit', [$body->id, 'body', 'hierarchical_attributes_edit']);
        $c->flash->{status_message} = _('Hierarchical attributes updated');
        $c->res->redirect($c->uri_for_action('/admin/bodies/attributes', [$body->id]));
    }
}

sub trim {
    my $self = shift;
    my $e = shift;
    $e =~ s/^\s+//;
    $e =~ s/\s+$//;
    return $e;
}

=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
