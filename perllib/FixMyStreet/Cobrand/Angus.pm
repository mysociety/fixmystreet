package FixMyStreet::Cobrand::Angus;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { return 2550; }
sub council_area { return 'Angus'; }
sub council_name { return 'Angus Council'; }
sub council_url { return 'angus'; }

sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    return 'https://fix.angus.gov.uk';
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter an Angus postcode, or street name and area';
}

sub example_places {
    return ( 'DD8 3AP', "Canmore Street" );
}

sub default_show_name { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => 'Angus',
        centre => '56.7240845983561,-2.91774391131183',
        span   => '0.525195055746977,0.985870680170788',
        bounds => [ 56.4616875530489, -3.40703662677109, 56.9868826087959, -2.4211659466003 ],
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub contact_email {
    my $self = shift;
    return join( '@', 'accessline', 'angus.gov.uk' );
}

=head2 temp_email_to_update, temp_update_contacts

Temporary helper routines to update the extra for potholes (temporary setup
hack, cargo-culted from Harrogate, may in future be superseded either by
Open311/integration or a better mechanism for manually creating rich contacts).

Can run with a script or command line like:

 bin/cron-wrapper perl -MFixMyStreet::App -MFixMyStreet::Cobrand::Angus -e \
 'FixMyStreet::Cobrand::Angus->new({c => FixMyStreet::App->new})->temp_update_contacts'

=cut

sub temp_update_contacts {
    my $self = shift;

    my $contact_rs = $self->{c}->model('DB::Contact');

    my $body = FixMyStreet::DB->resultset('Body')->search({
        'body_areas.area_id' => $self->council_area_id,
    }, { join => 'body_areas' })->first;

    my $_update = sub {
        my ($category, $field, $category_details) = @_;
        # NB: we're accepting just 1 field, but supply as array [ $field ]

        my $contact = $contact_rs->find_or_create(
            {
                body => $body,
                category => $category,
                %{ $category_details || {} },
            },
            {
                key => 'contacts_body_id_category_idx'
            }
        );

        my %default = (
            variable => 'true',
            order => '1',
            required => 'no',
            datatype => 'string',
            datatype_description => 'a string',
        );

        if ($field->{datatype} || '' eq 'boolean') {
            my $description = $field->{description};
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

        $contact->update({
            # XXX: we're just setting extra with the expected layout,
            # this could be encapsulated more nicely
            extra => { _fields => [ { %default, %$field } ] },
            confirmed => 1,
            deleted => 0,
            editor => 'automated script',
            whenedited => \'NOW()',
            note => 'Edited by script as per requirements Jan 2016',
        });
    };

    $_update->( 'Street lighting', {
            code => 'column_id',
            description => 'Lamp post number',
        });

}

1;
