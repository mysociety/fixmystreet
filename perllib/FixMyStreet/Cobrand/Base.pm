package FixMyStreet::Cobrand::Base;

use strict;
use warnings;

=head2 new

    my $cobrand = $class->new;
    my $cobrand = $class->new( { c => $c } );

Create a new cobrand object, optionally setting the context.

You probably shouldn't need to do this and should get the cobrand object via a
method in L<FixMyStreet::Cobrand> instead.

=cut

sub new {
    my $class = shift;
    my $self = shift || {};
    return bless $self, $class;
}

=head2 moniker

    $moniker = $cobrand_class->moniker();

Returns a moniker that can be used to identify this cobrand. By default this is
the last part of the class name lowercased - eg 'F::C::SomeCobrand' becomes
'somecobrand'.

=cut

sub moniker {
    my $class = ref( $_[0] ) || $_[0];    # deal with object or class
    my ($last_part) = $class =~ m{::(\w+)$};
    $last_part = lc($last_part);
    return $last_part;
}

=head2 is_default

    $bool = $cobrand->is_default();

Returns true if this is the default cobrand, false otherwise.

=cut

sub is_default {
    my $self = shift;
    return $self->moniker eq 'default';
}

=head2 setup_contacts, ensure_bodies

routines to update extra data for contacts.  These can be called by
a script:

    bin/setup-contacts zurich

=cut


sub get_body_for_contact {
    my ($self, $contact_data) = @_;
    if (my $body_name = $contact_data->{body_name}) {
        return $self->{c}->model('DB::Body')->find({ name => $body_name });
    }
    return;
    # TODO: for UK Councils use
    #   $self->{c}->model('DB::Body')->find(id => $self->council_id); 
    #   # NB: (or better that's the area in BodyAreas)
}

sub ensure_bodies {
    my ($self, $contact_data, $description) = @_;

    my @bodies = $self->body_details_data;

    my $bodies_rs = $self->{c}->model('DB::Body');

    for my $body (@bodies) {
        # following should work (having added Unique name/parent constraint, but doesn't)
        # $bodies_rs->find_or_create( $body, { $parent ? ( key => 'body_name_parent_key' ) : () }  );
        # let's keep it simple and just allow unique names
        next if $bodies_rs->search({ name => $body->{name} })->count;
        if (my $area_id = delete $body->{area_id}) {
            $body->{body_areas} = [ { area_id => $area_id } ];
        }
        my $parent = $body->{parent};
        if ($parent and ! ref $parent) {
            $body->{parent} = { name => $parent };
        }
        $bodies_rs->find_or_create( $body );
    }
}

=head2 body_details_data

Returns a list of bodies to create with ensure_body.  These
are mostly just passed to ->find_or_create, but there is some
pre-processing so that you can enter:

    area_id => 123,
    parent => 'Big Town',

instead of

    body_areas => [ { area_id => 123 } ],
    parent => { name => 'Big Town' },

For example:

    return (
        {
            name => 'Big Town',
        },
        {
            name => 'Small town',
            parent => 'Big Town',
            area_id => 1234,
        },
            

=cut

sub body_details_data {
    return ();
}

=head2 contact_details_data

Returns a list of contact_data to create with setup_contacts.
See Zurich for an example.

=cut

sub contact_details_data {
    return ()
}

sub ensure_contact {
    my ($self, $contact_data, $description) = @_;

    my $category = $contact_data->{category} or die "No category provided";
    $description ||= "Ensure contact exists $category";

    my $email = $self->temp_email_to_update; # will only be set if newly created

    my $body = $self->get_body_for_contact($contact_data) or die "No body found for $category";

    my $contact_rs = $self->{c}->model('DB::Contact');

    my $category_details = $contact_data->{category_details} || {};

    if (my $old_name = delete $contact_data->{rename_from}) {
        if (my $category = $contact_rs->find({
                category => $old_name,
            ,   body => $body,
            })) {
            $category->update({
                category => $category,
                whenedited => \'NOW()',
                note => "Renamed $description",
                %{ $category_details || {} },
            });
            return $category;
        }
    }

    if ($contact_data->{delete}) {
        my $contact = $contact_rs->search({
            body_id => $body->id,
            category => $category,
            deleted => 0
        });
        if ($contact->count) {
            print sprintf "Deleting: %s\n", $category;
            $contact->update({
                deleted => 1,
                editor => 'automated script',
                whenedited => \'NOW()',
                note => "Deleted by script $description",
            });
        }
        return;
    }

    return $contact_rs->find_or_create(
        {
            body => $body,
            category => $category,

            confirmed => 1,
            deleted => 0,
            email => $email,
            editor => 'automated script',
            note => 'created by automated script',
            send_method => '',
            whenedited => \'NOW()',
            %{ $category_details || {} },
        },
        {
            key => 'contacts_body_id_category_idx'
        }
    );
}

sub setup_contacts {
    my ($self, $description) = @_;

    my $c = $self->{c};
    die "Not a staging site, bailing out" unless $c->config->{STAGING_SITE}; # TODO, allow override via --force

    my @contact_details = $self->contact_details_data;

    for my $detail (@contact_details) {
        $self->update_contact( $detail, $description );
    }
}

sub update_contact {
    my ($self, $contact_data, $description) = @_; 

    my $c = $self->{c};

    my $contact_rs = $c->model('DB::Contact');

    my $category = $contact_data->{category} or die "No category provided";
    $description ||= "Update contact";

    my $contact = $self->ensure_contact($contact_data, $description)
        or return; # e.g. nothing returned if deleted

    if (my $fields = $contact_data->{fields}) {

        my @fields = map { $self->get_field_extra($_) } @$fields;
        my $note = sprintf 'Fields edited by automated script%s', $description ? " ($description)" : '';
        $contact->set_extra_fields(@fields);
        $contact->set_inflated_columns({
            confirmed => 1,
            deleted => 0,
            editor => 'automated script',
            whenedited => \'NOW()',
            note => "Updated fields $description",
        });
        $contact->update;
    }
}

sub get_field_extra {
    my ($self, $field) = @_;

    my %default = (
        variable => 'true',
        order => '1',
        required => 'no',
        datatype => 'string',
        datatype_description => 'a string',
    );

    if (($field->{datatype} || '') eq 'boolean') {
        %default = (
            %default,
            datatype => 'singlevaluelist',
            datatype_description => 'Yes or No',
            values => { value => [ 
                    { key => ['No'],  name => ['No'] },
                    { key => ['Yes'], name => ['Yes'] }, 
            ] },
        );
    }

    return { %default, %$field };
}

sub temp_email_to_update { 'test@example.com' } 

1;

