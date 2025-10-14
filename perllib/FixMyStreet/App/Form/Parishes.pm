package FixMyStreet::App::Form::Parishes;

use JSON::MaybeXS;
use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';
use utf8;

use Path::Tiny;
use File::Copy;
use Digest::SHA qw(sha1_hex);
use File::Basename;

has c => ( is => 'ro' );

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Wizard' );

has finished_action => ( is => 'ro' );

has '+is_html5' => ( default => 1 );

before _process_page_array => sub {
    my ($self, $pages) = @_;
    foreach my $page (@$pages) {
        $page->{type} = $self->default_page_type
            unless $page->{type};
    }
};

# Add some functions to the form to pass through to the current page
has '+current_page' => (
    handles => {
        intro_template => 'intro',
        title => 'title',
        template => 'template',
    }
);

has_page intro => (
    fields => ['name', 'email', 'parish', 'logo', 'logo_fileid', 'continue'],
    title => 'FixMyStreet for Town/Parish Councils',
    intro => 'start.html',
    next => 'categories',
);

has_page categories => (
    fields => ['categories', 'add_category', 'continue'],
    title => 'Pick your categories',
    intro => 'categories.html',
    update_field_list => sub {
        my $form = shift;
        my $c = $form->c;
        my $parish = $form->saved_data->{parish};
        my $area = FixMyStreet::MapIt::call("area/$parish.geojson");
        my $coord = $area->{coordinates}[0][0];
        $coord = $coord->[0] if $area->{type} eq 'MultiPolygon';
        my ($lon, $lat) = @$coord;

        $c->stash->{latitude} = $lat;
        $c->stash->{longitude} = $lon;
        $c->forward('/council/load_and_check_areas', []);
        $c->forward('/report/new/setup_categories_and_bodies', []);

        #my $areas = FixMyStreet::MapIt::call('area/covered', $parish, type => $c->cobrand->area_types);
        # my @bodies = FixMyStreet::DB->resultset('Body')->active->search({
        #     name => { -not_in => ['TfL', 'National Highways'] }
        # }, {
        #     prefetch => 'body_areas',
        # })->for_areas(keys %$areas)->all;
        # my @categories = FixMyStreet::DB->resultset('Contact')->active->search({
        #     body_id => [ map { $_->id } @bodies ],
        # })->all_sorted;
        # $c->stash->{categories} = \@categories;
        return {};
    },
    next => 'summary',
);

has_page summary => (
    fields => ['payment'],
    tags => { hide => 1 },
    title => 'Review your answers',
    template => 'parishes/summary.html',
    finished => sub {
        my $form = shift;
        my $c = $form->c;
        my $success = $c->forward('process_parish', [ $form ]);
        if (!$success) {
            $form->add_form_error('Something went wrong, please try again');
            foreach (keys %{$c->stash->{field_errors}}) {
                $form->add_form_error("$_: " . $c->stash->{field_errors}{$_});
            }
        }
        return $success;
    },
    next => 'done',
);

has_page done => (
    tags => { hide => 1 },
    title => 'Success',
    template => 'parishes/confirmation.html',
);

has_field name => (
    type => 'Text',
    label => 'Your name',
    required => 1,
);

has_field email => (
    required => 1,
    type => 'Email',
    label => 'Email address to receive reports',
    tags => {
        hint => 'Please use an email given on your parish website, or other verifiable contact',
    },
);

has_field parish => (
    type => 'Select',
    required => 1,
    empty_select => 'Please pick your town/parish council',
    label => 'Please select your town/parish council from the list',
    tags => {
        autocomplete => 1,
        hint => 'You can type in the box to search or scroll through the list',
    },
    validate_method => sub {
        my $self = shift;
        my $v = $self->value;
        my $existing = FixMyStreet::DB->resultset("Body")->search(
            { 'body_areas.area_id' => $v }, { join => 'body_areas' })->first;
        if ($existing) {
            # TODO Also if it is in Buckinghamshire?
            $self->add_error('That parish already exists in our system :)');
            my $c = $self->form->c;
            $c->res->redirect('/parishes/existing?body=' . $existing->id);
            $c->detach;
        }
    },
);

sub options_parish {
    my $areas = decode_json(path(FixMyStreet->path_to('data/parishes.json'))->slurp_utf8);
    return @$areas;
}

has_field logo_fileid => (
    type => 'FileIdPhoto',
    num_photos_required => 0,
    linked_field => 'logo',
);

has_field logo => (
    type => 'Photo',
    tags => {
        max_photos => 1,
        hint => 'If you don’t have a logo, you can skip this step',
    },
    label => 'Please provide a logo to use on your all reports page',
);

# TODO Need to make sure there's at least one?
has_field categories => (
    type => 'Repeatable',
    setup_for_js => 1,
    label => 'Category name',
    validate_method => sub {
        my $self = shift;
        my $v = $self->value;
        if (!@$v) {
            $self->add_error('Please provide at least one category');
        }
    }
);
has_field 'categories.name' => (
    type => 'Text',
    label => 'Category name',
);
has_field add_category => (
    type => 'AddElement',
    repeatable => 'categories',
    value => 'Add another category',
    tags => { hide => 1 },
);
has_field 'categories.rm_category' => (
    type => 'RmElement',
    repeatable => 'categories',
    value => 'Remove category',
    do_wrapper => 0,
    tags => {
        wrapper_tag => 'button',
    }
);

# From HTML/FormHandler/Render/RepeatableJs.pm altered to not use jQuery and no level
sub render_repeatable_js {
    my $self = shift;
    return '' unless $self->has_for_js;

    my $for_js = $self->for_js;
    my %index;
    my %html;
    foreach my $key ( keys %$for_js ) {
        $index{$key} = $for_js->{$key}->{index};
        $html{$key} = $for_js->{$key}->{html};
    }
    my $index_str = encode_json( \%index );
    my $html_str = encode_json( \%html );
    my $js = <<EOS;
var rep_index = $index_str;
var rep_html = $html_str;

    document.querySelector('.add_element').addEventListener('click', function() {
    // get the repeatable id
    var data_rep_id = this.dataset.repId;
    // create a regex out of index placeholder
    var re = new RegExp('{index-1}',"g");
    // replace the placeholder in the html with the index
    var index = rep_index[data_rep_id];
    var html = rep_html[data_rep_id];
    html = html.replace(re, index);
    // escape dots in element id
    var esc_rep_id = data_rep_id.replace(/[.]/g, '\\\\.');
    // append new element in the 'controls' div of the repeatable
    var rep_controls = document.querySelector('#form-' + esc_rep_id + '-row');
    var d = document.createElement('div');
    d.innerHTML = html;
    rep_controls.append(d);
    // increment index of repeatable fields
    index++;
    rep_index[data_rep_id] = index;
  });

// Needs to listen to parent on any such child
  document.addEventListener('click', function(event) {
  if (event.target.closest('.rm_element')) {
    var id = event.target.dataset.repElemId;
    var esc_id = id.replace(/[.]/g, '\\\\.');
    var rm_elem = document.querySelector('#' + esc_id);
    rm_elem.remove();
    event.preventDefault();
  }
  });

EOS
    return $js;
}


has_field continue => ( type => 'Submit', value => 'Continue', element_attr => { class => 'govuk-button' } );
has_field payment => ( type => 'Submit', value => 'Continue to payment', element_attr => { class => 'govuk-button' } );

sub fields_for_display {
    my ($form) = @_;

     my $things = [];
     for my $page ( @{ $form->pages } ) {
         my $x = {
             stage => $page->{name},
             title => $page->{title},
             ( $page->tag_exists('hide') ? ( hide => $page->get_tag('hide') ) : () ),
             fields => []
         };

         for my $f ( @{ $page->fields } ) {
             my $field = $form->field($f);
             next if $field->type eq 'Submit';
             my $value = $form->saved_data->{$field->{name}} || '';
             push @{$x->{fields}}, {
                 name => $field->{name},
                 desc => $field->{label},
                 type => $field->type,
                 pretty => $form->format_for_display( $field->{name}, $value ),
                 value => $value,
                 ( $field->tag_exists('block') ? ( block => $field->get_tag('block') ) : () ),
                 ( $field->tag_exists('hide') ? ( hide => $field->get_tag('hide') ) : () ),
             };
         }

         push @$things, $x;
     }

     return $things;
}

sub format_for_display {
    my ($form, $field_name, $value) = @_;
    my $field = $form->field($field_name);
    if ( $field->{type} eq 'Select' ) {
        return $form->c->stash->{label_for_field}($form, $field_name, $value);
    } elsif ( $field->{type} eq 'DateTime' ) {
        # if field was on the last screen then we get the DateTime and not
        # the hash because it's not been through the freeze/that process
        if ( ref $value eq 'DateTime' ) {
            return join( '/', $value->day, $value->month, $value->year);
        } else {
            return "" unless $value;
            return "$value->{day}/$value->{month}/$value->{year}";
        }
    } elsif ( $field->{type} eq 'Repeatable' ) {
        return join ('; ', map { $_->{name} } @$value);
    }

    return $value;
}

1;
