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
    fields => ['name', 'email', 'continue'],
    title => 'FixMyStreet for Town/Parish Councils',
    intro => 'start.html',
    next => sub {
        my $data = $_[0];
        my $email = $data->{email};
        my $parish_email = 0;
        # TODO Check email against parish domain list
        if ($parish_email) {
            # Set data for matched parish, straight to categories page
            $data->{parish} = $parish_email;
            return 'categories';
        } else {
            return 'pick_parish';
        }
    },
);

has_page pick_parish => (
    fields => ['parish', 'continue'],
    title => 'FixMyStreet for Town/Parish Councils – pick your parish',
    intro => '',
    next => 'categories',
);

# TODO On this page load, it needs to check if there already is a body for this parish (whether it's come from domain or picked from list), and/or if it's a Bucks one, and stop process here with special message. If easier, could be done at submission of both intro and pick_parish, I guess, but start of here would be cleaner
# TODO This page needs to load the existing categories covering the parish, either just for info (if we only let them create categories with different names) or to explain how they can 'take over' receiving reports within their boundary for a particular existing category
has_page categories => (
    fields => ['delivery', 'categories', 'add_category', 'continue'],
    title => 'FixMyStreet for Town/Parish Councils – pick your categories',
    intro => 'categories.html',
    next => 'summary',
);

has_page summary => (
    fields => ['submit'],
    tags => { hide => 1 },
    title => 'Review',
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
    label => 'Name',
    required => 1,
);

has_field email => (
    required => 1,
    type => 'Email',
    label => 'Email address',
    tags => {
        hint => 'If possible, please use an email at your parish website domain',
    },
);

has_field parish => (
    type => 'Select',
    required => 1,
    empty_select => 'Please pick your town/parish council',
    label => 'Please pick your town/parish council',
    tags => { autocomplete => 1 },
);

sub options_parish {
    # TODO Cache this locally as is quite slow to fetch all the data, and does it more than once
    use LWP::Simple;
    my $areas = mySociety::MaPit::call('areas', 'CPC');
    my %count;
    my %parents;
    foreach (values %$areas) {
        $count{$_->{name}}++;
    }
    foreach (values %$areas) {
        if ($count{$_->{name}} > 1) {
            $parents{$_->{parent_area}} = 1;
        }
    }
    my $parents = mySociety::MaPit::call('areas', [ keys %parents ]);
    my @out = map {
        my $label = $_->{name};
        if ($count{$label} > 1) {
            my $parent = $parents->{$_->{parent_area}};
            $label .= " (" . $parent->{name} . ")";
        }
        { label => $label, value => $_->{id} },
    } sort { $a->{name} cmp $b->{name} } values %$areas;
    return @out;
}

has_field delivery => (
    required => 1,
    type => 'Email',
    label => 'Email address to receive reports',
    tags => {
        hint => 'If possible, please use an email at your parish website domain',
    },
);

# TODO This will need some good guidance (e.g. “village green” or “Foo playing field” or what have you)
# TODO Need to make sure there's at least one?
# TODO See page message above - as well as this for new categories, probably needs to show existing categories covering the parish, either just for info (if we only let them create categories with different names) or to explain how they can 'take over' receiving reports within their boundary for a particular existing category
has_field categories => ( type => 'Repeatable', setup_for_js => 1, label => 'Category name' );
has_field 'categories.contains' => ( type => 'Text', label => 'Category name' );
has_field add_category => ( type => 'AddElement', repeatable => 'categories', value => 'Add another category', tags => { hide => 1 } );
has_field 'categories.rm_category' => ( type => 'RmElement', repeatable => 'categories', value => 'Remove category' );

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
    cont = confirm('Remove?');
    if (cont) {
      var id = event.target.dataset.repElemId;
      var esc_id = id.replace(/[.]/g, '\\\\.');
      var rm_elem = document.querySelector('#' + esc_id);
      rm_elem.remove();
    }
    event.preventDefault();
  }
  });

EOS
    return $js;
}


has_field continue => ( type => 'Submit', value => 'Continue', element_attr => { class => 'govuk-button' } );
has_field submit => ( type => 'Submit', value => 'Submit', element_attr => { class => 'govuk-button' } );

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
        return join ('; ', map { $_->{contains} } @$value);
    }

    return $value;
}

1;
