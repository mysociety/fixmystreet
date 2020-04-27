package FixMyStreet::App::Controller::Admin::Bodies;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use POSIX qw(strcoll);
use mySociety::EmailUtil qw(is_valid_email_list);
use FixMyStreet::MapIt;
use FixMyStreet::SendReport;

=head1 NAME

FixMyStreet::App::Controller::Admin::Bodies - Catalyst Controller

=head1 DESCRIPTION

Admin pages

=head1 METHODS

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    if (my $body_id = $c->get_param('body')) {
        return $c->res->redirect( $c->uri_for_action('admin/bodies/edit', [ $body_id ] ) );
    }

    if (!$c->user->is_superuser && $c->user->from_body && $c->cobrand->moniker ne 'zurich') {
        return $c->res->redirect( $c->uri_for_action('admin/bodies/edit', [ $c->user->from_body->id ] ) );
    }

    $c->forward( '/auth/get_csrf_token' );

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

    $c->forward( '/admin/fetch_languages' );
    $c->forward( 'fetch_translations' );

    my $posted = $c->get_param('posted') || '';
    if ( $posted eq 'body' ) {
        $c->forward('update_body', [ undef, _('New body added') ]);
    }

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

    $c->forward( 'body_form_dropdowns' );

    return 1;
}

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

sub edit : Chained('body') : PathPart('') : Args(0) {
    my ( $self, $c ) = @_;

    unless ($c->user->has_permission_to('category_edit', $c->stash->{body_id})) {
        $c->forward('check_for_super_user');
    }

    $c->forward( '/auth/get_csrf_token' );
    $c->forward( '/admin/fetch_all_bodies' );
    $c->forward( 'body_form_dropdowns' );
    $c->forward('/admin/fetch_languages');

    if ( $c->get_param('posted') ) {
        $c->forward('update_contacts');
    }

    $c->stash->{object} = $c->stash->{body};
    $c->stash->{translation_col} = 'name';

    # if there's a contact then it's because we're displaying error
    # messages about adding a contact so grabbing translations will
    # fetch the contact submitted translations. So grab them, stash
    # them and then clear posted so we can fetch the body translations
    if ($c->stash->{contact}) {
        $c->forward('fetch_translations');
        $c->stash->{contact_translations} = $c->stash->{translations};
    }
    $c->set_param('posted', '');

    $c->forward('fetch_translations');

    # don't set this last as fetch_contacts might over-ride it
    # to display email addresses as text
    $c->stash->{template} = 'admin/bodies/body.html';
    $c->forward('/admin/fetch_contacts');
    $c->stash->{contacts} = [ $c->stash->{contacts}->all ];
    $c->forward('/report/stash_category_groups', [ $c->stash->{contacts}, 0 ]);

    return 1;
}

sub category : Chained('body') : PathPart('') {
    my ( $self, $c, @category ) = @_;
    my $category = join( '/', @category );

    $c->forward( '/auth/get_csrf_token' );

    my $contact = $c->stash->{body}->contacts->search( { category => $category } )->first;
    $c->detach( '/page_error_404_not_found', [] ) unless $contact;
    $c->stash->{contact} = $c->stash->{current_contact} = $contact;

    $c->stash->{translation_col} = 'category';
    $c->stash->{object} = $c->stash->{contact};

    $c->forward('/admin/fetch_languages');
    $c->forward('fetch_translations');

    my $history = $c->model('DB::ContactsHistory')->search(
        {
            body_id => $c->stash->{body_id},
            category => $c->stash->{contact}->category
        },
        {
            order_by => ['contacts_history_id']
        },
    );
    $c->stash->{history} = $history;
    my @methods = map { $_ =~ s/FixMyStreet::SendReport:://; $_ } sort keys %{ FixMyStreet::SendReport->get_senders };
    $c->stash->{send_methods} = \@methods;

    return 1;
}

sub body_form_dropdowns : Private {
    my ( $self, $c ) = @_;

    my $areas;
    my $whitelist = $c->config->{MAPIT_ID_WHITELIST};

    if ( $whitelist && ref $whitelist eq 'ARRAY' && @$whitelist ) {
        $areas = FixMyStreet::MapIt::call('areas', $whitelist);
    } else {
        $areas = FixMyStreet::MapIt::call('areas', $c->cobrand->area_types);
    }

    # Some cobrands may want to add extra areas at runtime beyond those
    # available via MAPIT_WHITELIST or MAPIT_TYPES. This can be used for,
    # e.g., parish councils on a particular council cobrand.
    $areas = $c->cobrand->call_hook("add_extra_areas" => $areas) || $areas;

    $c->stash->{areas} = [ sort { strcoll($a->{name}, $b->{name}) } values %$areas ];

    my @methods = map { $_ =~ s/FixMyStreet::SendReport:://; $_ } sort keys %{ FixMyStreet::SendReport->get_senders };
    $c->stash->{send_methods} = \@methods;
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

sub update_contacts : Private {
    my ( $self, $c ) = @_;

    my $posted = $c->get_param('posted') || '';
    if ( $posted eq 'new' ) {
        $c->forward('update_contact');
    } elsif ( $posted eq 'update' ) {
        $c->forward('confirm_contacts');
    } elsif ( $posted eq 'body' ) {
        $c->forward('update_body', [ $c->stash->{body}, _('Values updated') ]);
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
        # Changed name
        $contact = $current_contact;
        $c->model('DB::Problem')->to_body($c->stash->{body_id})->search({ category => $current_category })->update({ category => $category });
        $contact->category($category);
    }

    my $email = $c->get_param('email');
    $email =~ s/\s+//g;
    my $send_method = $c->get_param('send_method') || $contact->body->send_method || "";
    my $email_unchanged = $contact->email && $email && $contact->email eq $email;
    unless ( $send_method eq 'Open311' || $email_unchanged ) {
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
    if ( $c->get_param('photo_required') ) {
        $contact->set_extra_metadata_if_undefined(  photo_required => 1 );
    } else {
        $contact->unset_extra_metadata( 'photo_required' );
    }
    if ( $c->get_param('open311_protect') ) {
        $contact->set_extra_metadata( open311_protect => 1 );
    } else {
        $contact->unset_extra_metadata( 'open311_protect' );
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

    # Special form disabling form
    if ($c->get_param('disable')) {
        my $msg = $c->get_param('disable_message');
        $msg = FixMyStreet::Template::sanitize($msg);
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
        $c->stash->{updated} = _('Values updated');
        $c->forward('/admin/log_edit', [ $contact->id, 'category', 'edit' ]);
        # NB: History is automatically stored by a trigger in the database
        $contact->update;
    } else {
        $c->stash->{updated} = _('New category contact added');
        $contact->insert;
        $c->forward('/admin/log_edit', [ $contact->id, 'category', 'add' ]);
    }

    unless ( %errors ) {
        $c->stash->{translation_col} = 'category';
        $c->stash->{object} = $contact;
        $c->forward('update_translations');
    }

}

sub confirm_contacts : Private {
    my ( $self, $c ) = @_;

    $c->forward('/auth/check_csrf_token');

    my @categories = $c->get_param_list('confirmed');

    my $contacts = $c->model('DB::Contact')->search(
        {
            body_id => $c->stash->{body_id},
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

    $c->forward('/admin/log_edit', [ $c->stash->{body_id}, 'body', 'edit' ]);
    $c->stash->{updated} = _('Values updated');
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
    my @current = $body->body_areas->all;
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

    $c->stash->{updated} = $msg;
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
    );
    my %params = map { $_ => $c->get_param($_) || $defaults{$_} } keys %defaults;
    $c->forward('check_body_params', [ \%params ]);

    my @extras = qw/fetch_all_problems/;
    my $cobrand_extras = $c->cobrand->call_hook('body_extra_fields');
    push @extras, @$cobrand_extras if $cobrand_extras;

    %defaults = map { $_ => '' } @extras;
    my %extras = map { $_ => $c->get_param("extra[$_]") || $defaults{$_} } @extras;
    return { params => \%params, extras => \%extras };
}

sub check_body_params : Private {
    my ( $self, $c, $params ) = @_;

    $c->stash->{body_errors} ||= {};

    unless ($params->{name}) {
        $c->stash->{body_errors}->{name} = _('Please enter a name for this body');
    }
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
    if ($c->get_param('posted')) {
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
