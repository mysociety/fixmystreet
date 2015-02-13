package FixMyStreet::Cobrand::Harrogate;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;
use feature 'say';

sub council_id { return 2407; }
sub council_area { return 'Harrogate'; }
sub council_name { return 'Harrogate Borough Council'; }
sub council_url { return 'harrogate'; }
sub is_two_tier { return 1; } # with North Yorkshire CC 2235

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Harrogate';

    # as it's the requested example location, try to avoid a disambiguation page
    $town .= ', HG1 1DH' if $string =~ /^\s*king'?s\s+r(?:oa)?d\s*(?:,\s*har\w+\s*)?$/i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '54.0671557690306,-1.59581319536637',
        span   => '0.370193897090822,0.829517054931808',
        bounds => [ 53.8914112467619, -2.00450542308575, 54.2616051438527, -1.17498836815394 ],
    };
}

sub example_places {
    return ( 'HG1 2SG', "King's Road" );
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a Harrogate district postcode, or street name and area';
}

# increase map zoom level so street names are visible
sub default_map_zoom { return 3; }


=head2 temp_email_to_update, temp_update_contacts

Temporary helper routines to update the extra for potholes (temporary setup
hack, cargo-culted from ESCC, may in future be superseded either by
Open311/integration or a better mechanism for manually creating rich contacts).

Can run with a script or command line like:

 bin/cron-wrapper perl -MFixMyStreet::App -MFixMyStreet::Cobrand::Harrogate -e \
 'FixMyStreet::Cobrand::Harrogate->new({c => FixMyStreet::App->new})->temp_update_contacts'

=cut

sub temp_email_to_update {
    return 'CustomerServices@harrogate.gov.uk';
}

sub temp_update_contacts {
    my $self = shift;

    my $contact_rs = $self->{c}->model('DB::Contact');

    my $email = $self->temp_email_to_update;
    my $_update = sub {
        my ($category, $field, $category_details) = @_; 
        # NB: we're accepting just 1 field, but supply as array [ $field ]

        my $contact = $contact_rs->find_or_create(
            {
                body_id => $self->council_id,
                category => $category,

                confirmed => 1,
                deleted => 0,
                email => $email,
                editor => 'automated script',
                note => '',
                send_method => '',
                whenedited => \'NOW()',
                %{ $category_details || {} },
            },
            {
                key => 'contacts_body_id_category_idx'
            }
        );

        say "Editing category: $category";

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
            note => 'Edited by script as per requirements Dec 2014',
        });
    };

    $_update->( 'Abandoned vehicles', {
            code => 'registration',
            description => 'Vehicle Registration number:',
        });

    $_update->( 'Dead animals', {
            code => 'INFO_TEXT',
            variable => 'false',
            description => 'We do not remove small species, e.g. squirrels, rabbits, and small birds.',
        });

    $_update->( 'Flyposting', {
            code => 'offensive',
            description => 'Is it offensive?',
            datatype => 'boolean', # mapped onto singlevaluelist
        });

    $_update->( 'Flytipping', {
            code => 'size',
            description => 'Size?',
            datatype => 'singlevaluelist',
            values => { value => [ 
                    { key => ['Single Item'],       name => ['Single item'] },
                    { key => ['Car boot load'],     name => ['Car boot load'] },
                    { key => ['Small van load'],    name => ['Small van load'] },
                    { key => ['Transit van load'],  name => ['Transit van load'] },
                    { key => ['Tipper lorry load'], name => ['Tipper lorry load'] },
                    { key => ['Significant load'],  name => ['Significant load'] },
                ] },
        });

    $_update->( 'Graffiti', {
            code => 'offensive',
            description => 'Is it offensive?',
            datatype => 'boolean', # mapped onto singlevaluelist
        });

    $_update->( 'Parks and playgrounds', {
            code => 'dangerous',
            description => 'Is it dangerous or could cause injury?',
            datatype => 'boolean', # mapped onto singlevaluelist
        });

    $_update->( 'Trees', {
            code => 'dangerous',
            description => 'Is it dangerous or could cause injury?',
            datatype => 'boolean', # mapped onto singlevaluelist
        });

    # also ensure that the following categories are created:
    for my $category (
        'Car parking',
        'Dog and litter bins',
        'Dog fouling',
        'Other',
        'Rubbish (refuse and recycling)',
        'Street cleaning',
        'Street lighting',
        'Street nameplates',
    ) {
        say "Creating $category if required";
        my $contact = $contact_rs->find_or_create(
            {
                body_id => $self->council_id,
                category => $category,
                confirmed => 1,
                deleted => 0,
                email => $email,
                editor => 'automated script',
                note => 'Created by script as per requirements Dec 2014',
                send_method => '',
                whenedited => \'NOW()',
            }
        );
    }

    my @to_delete = (
        'Parks/landscapes', # delete in favour of to parks and playgrounds
        'Public toilets',   # as no longer in specs
    );
    say sprintf "Deleting: %s (if present)", join ',' => @to_delete;
    $contact_rs->search({
        body_id => $self->council_id,
        category => \@to_delete,
        deleted => 0
    })->update({
        deleted => 1,
        editor => 'automated script',
        whenedited => \'NOW()',
        note => 'Deleted by script as per requirements Dec 2014',
    });
}

sub contact_email {
    my $self = shift;
    return join( '@', 'customerservices', 'harrogate.gov.uk' );
}

sub process_additional_metadata_for_email {
    my ($self, $problem, $h) = @_;

    my $additional = '';
    if (my $extra = $problem->get_extra_fields) {
        $additional = join "\n\n", map {
            if ($_->{name} eq 'INFO_TEXT') {
                ();
            }
            else {
                sprintf '%s: %s', $_->{description}, $_->{value};
            }
        } @$extra;
        $additional = "\n\n$additional" if $additional;
    }

    $h->{additional_information} = $additional;
}

sub send_questionnaires {
    return 0;
}

sub munge_category_list {
    my ($self, $categories_ref, $contacts_ref, $extras_ref) = @_;

    # we want to know which contacts *only* belong to NYCC
    # that's because for shared responsibility, we don't expect
    # the user to have to figure out which authority to contact.

    # so we start building up the list of both
    my (%harrogate_contacts, %nycc_contacts);

    my $harrogate_id = $self->council_id; # XXX: note reference to council_id as body id!
    for my $contact (@$contacts_ref) {
        my $category = $contact->category;
        if ($contact->body_id == $harrogate_id) {
            $harrogate_contacts{$category} = 1;
        }
        else {
            $nycc_contacts{$category}++;
        }
    }

    # and then remove any that also have Harrogate involvement
    delete $nycc_contacts{$_} for keys %harrogate_contacts;

    # here, we simply *mark* the text with (NYCC) at the end, and
    # the rest will get done in the template with javascript
    my @categories = map {
        $nycc_contacts{$_} ?
            "$_ (NYCC)"
            : $_
    } @$categories_ref;

    # replace the entire list with this transformed one
    @$categories_ref = @categories;
}

1;

