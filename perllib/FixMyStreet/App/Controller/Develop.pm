package FixMyStreet::App::Controller::Develop;
use Moose;
use namespace::autoclean;

use File::Basename;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Develop - Catalyst Controller

=head1 DESCRIPTION

Developer-helping Catalyst Controller.

=head1 METHODS

=over 4

=item auto

Makes sure this controller is only available when run in development.

=cut

sub auto : Private {
    my ($self, $c) = @_;
    $c->detach( '/page_error_404_not_found' ) unless $c->config->{STAGING_SITE};
    return 1;
}

=item email_list

Shows a list of links to preview HTML emails.

=cut

sub email_list : Path('/_dev/email') : Args(0) {
    my ( $self, $c ) = @_;

    my @include_path = @{ $c->cobrand->path_to_email_templates($c->stash->{lang_code}) };
    push @include_path, $c->view('Email')->config->{INCLUDE_PATH}->[0];
    my %templates;
    foreach (@include_path) {
        $templates{$_} = 1 for grep { /^[^_]/ } map { s/\.html$//; basename $_ } glob "$_/*.html";
    }

    my %with_update = ('update-confirm' => 1, 'other-updated' => 1);
    my %with_problem = ('alert-update' => 1, 'other-reported' => 1,
        'problem-confirm' => 1, 'problem-confirm-not-sending' => 1,
        'problem-moderated' => 1, 'questionnaire' => 1, 'submit' => 1);

    my $update = $c->model('DB::Comment')->first;
    my $problem = $c->model('DB::Problem')->first;

    $c->stash->{templates} = [];
    foreach (sort keys %templates) {
        my $url = $c->uri_for('/_dev/email', $_);
        $url .= "?problem=" . $problem->id if $problem && $with_problem{$_};
        $url .= "?update=" . $update->id if $update && $with_update{$_};
        push @{$c->stash->{templates}}, { name => $_, url => $url };
    }
}

=item email_previewer

Previews an HTML email template. A problem or update ID can be provided as a
query parameter, and other data is taken from the database.

=back

=cut

sub email_previewer : Path('/_dev/email') : Args(1) {
    my ( $self, $c, $template ) = @_;

    my $vars = {};
    if (my $id = $c->get_param('update')) {
        $vars->{update} = $c->model('DB::Comment')->find($id);
        $vars->{problem} = $vars->{report} = $vars->{update}->problem;
    } elsif ($id = $c->get_param('problem')) {
        $vars->{problem} = $vars->{report} = $c->model('DB::Problem')->find($id);
    }

    # Special case needed variables
    if ($template =~ /^alert-problem/) {
        $vars->{area_name} = 'Area Name';
        $vars->{ward_name} = 'Ward Name';
        $vars->{data} = [ $c->model('DB::Problem')->search({}, { rows => 5 })->all ];
    } elsif ($template eq 'alert-update') {
        $vars->{data} = [];
        my $q = $c->model('DB::Comment')->search({}, { rows => 5 });
        while (my $u = $q->next) {
            my $fn = sub {
                return FixMyStreet::App::Model::PhotoSet->new({
                    db_data => $u->photo,
                })->get_image_data( num => 0, size => 'fp' );
            };
            push @{$vars->{data}}, {
                item_photo => $u->photo, get_first_image_fp => $fn, item_text => $u->text,
                item_name => $u->name, item_anonymous => $u->anonymous, confirmed => $u->confirmed };
        }
    } elsif ($template eq 'questionnaire') {
        $vars->{created} = 'N weeks';
    }

    my $email = $c->construct_email("$template.txt", $vars);

    # Look through the Email::MIME email for the text/html part, and any inline
    # images. Turn the images into data: URIs.
    my $html = '';
    my %images;
    $email->walk_parts(sub {
        my ($part) = @_;
        return if $part->subparts;
        if ($part->content_type =~ m[^image/]i) {
            (my $cid = $part->header('Content-ID')) =~ s/[<>]//g;
            (my $ct = $part->content_type) =~ s/;.*//;
            $images{$cid} = "$ct;base64," . $part->body_raw;
        } elsif ($part->content_type =~ m[text/html]i) {
            $html = $part->body_str;
        }
    });

    foreach (keys %images) {
        $html =~ s/cid:([^"]*)/data:$images{$1}/g;
    }

    $c->response->body($html);
}

__PACKAGE__->meta->make_immutable;

1;

