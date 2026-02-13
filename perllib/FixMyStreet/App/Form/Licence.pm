package FixMyStreet::App::Form::Licence;

use strict;
use warnings;

# Discover and load all form classes in FixMyStreet::App::Form::Licence::*
use Module::Pluggable
    sub_name    => '_forms',
    search_path => 'FixMyStreet::App::Form::Licence',
    except => qr/Base/,
    require     => 1;

my @ALL_FORM_CLASSES = __PACKAGE__->_forms;

# Build licence types from discovered form classes
sub licence_types {
    my $self = shift;
    my %types;
    for my $class (@ALL_FORM_CLASSES) {
        next unless $class->can('type') && $class->can('name');
        my $type = $class->type;
        $types{$type} = {
            class => $class,
            name  => $class->name,
        };
    }
    return \%types;
}

sub generate_pdf {
    my ($self, $report) = @_;

    my $type = $report->get_extra_metadata('licence_type') or return;
    my $licence_config = $self->licence_types->{lc $type} or return;

    my $form = $licence_config->{class}->new(
        page_name => 'intro',
        saved_data => $report->extra,
        no_preload => 1,
    );

    require FixMyStreet::PDF;
    my $pdf = FixMyStreet::PDF->new(
        title => $report->title . ', FMS' . $report->id,
        font => 'Johnston100',
    );

    # Simplest solution, have a template that has the HTML in,
    # and let it place it all. This works, but has orphans.
    #my $input = $c->render_fragment('licence/summary_pdf.html');
    #$pdf->plot_line(undef, 'black', $input);

    # So instead, generate the PDF line by line and check for
    # orphan headings as we go

    my ($rc, $next_y);
    ($rc, $next_y) = $pdf->plot_line($next_y, 'black', '<h1>' . $form->title . '</h1>');
    ($rc, $next_y) = $pdf->plot_line($next_y, 'black', '<p>FMS' . $report->id . '</p>');

    foreach my $page (@{$form->fields_for_display}) {
        next if $page->{hide};
        next if $page->{stage} eq 'intro' || $page->{stage} eq 'done';

        my $page_title = "<h2>$page->{title}</h2>";
        my ($rc, $post_title_y) = $pdf->plot_line($next_y, 'white', $page_title);
        if ($rc) {
            # Want to start heading on new page
            $next_y = undef;
        }

        my $first_field = 1;
        foreach my $field (@{$page->{fields}}) {
            next if $field->{hide};
            my $line = "<p style='margin-top:6pt'><strong>$field->{desc}";
            $line .= ':' unless $field->{desc} =~ /[?:.]$/;
            $line .= "</strong> $field->{pretty}</p>";

            if ($first_field) {
                $first_field = 0;
                if ($post_title_y) {
                    # Can we fit the line of text in after the heading?
                    ($rc) = $pdf->plot_line($post_title_y, 'white', $line);
                    if ($rc) {
                        # Heading would be an orphan, want to start it on new page
                        $next_y = undef;
                    }
                }
                ($rc, $next_y) = $pdf->plot_line($next_y, '#0019A8', $page_title);
            }
            ($rc, $next_y) = $pdf->plot_line($next_y, 'black', $line);

            # Special showing of calculated end date
            if ($field->{desc} eq 'Number of weeks required') {
                my $end = $form->saved_data->{proposed_end_date};
                my $line = '<p style="margin-top:6pt"><strong>Proposed end date:';
                $line .= "</strong> $end->{day}/$end->{month}/$end->{year}</p>";
                ($rc, $next_y) = $pdf->plot_line($next_y, 'black', $line);
            }
        }
    }

    return $pdf->to_string;
}

1;
