package FixMyStreet::App::Controller::Photo;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

use JSON::MaybeXS;
use Path::Tiny;
use Try::Tiny;
use FixMyStreet::App::Model::PhotoSet;

=head1 NAME

FixMyStreet::App::Controller::Photo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

Display a photo

=cut

sub during :LocalRegex('^(temp|fulltemp)\.([0-9a-f]{40}\.(?:jpeg|png|gif|tiff))$') {
    my ( $self, $c ) = @_;
    my ( $size, $filename ) = @{ $c->req->captures };

    my $photoset = FixMyStreet::App::Model::PhotoSet->new({
        data_items => [ $filename ]
    });

    $size = $size eq 'temp' ? 'default' : 'full';
    my $photo = $photoset->get_image_data(size => $size, default => $c->cobrand->default_photo_resize);

    if (!FixMyStreet->config('LOGIN_REQUIRED')) {
        path(FixMyStreet->path_to('web', 'photo'))->mkdir;
        my $out = FixMyStreet->path_to('web', $c->req->path);
        path($out)->spew_raw($photo->{data});
    }

    $c->forward( 'output', [ $photo ] );
}

sub index :LocalRegex('^(c/)?([1-9]\d*)(?:\.(\d+))?(?:\.(full|tn|fp|og))?\.(?:jpeg|png|gif|tiff)$') {
    my ( $self, $c ) = @_;
    my ( $is_update, $id, $photo_number, $size ) = @{ $c->req->captures };

    $photo_number ||= 0;
    $size ||= '';

    my $item;
    if ( $is_update ) {
        ($item) = $c->cobrand->updates->search( {
            'me.id' => $id,
            'me.state' => 'confirmed',
            'problem.state' => [ FixMyStreet::DB::Result::Problem->visible_states() ],
            'me.photo' => { '!=', undef },
        }, { prefetch => 'problem' });
    } else {
        ($item) = $c->cobrand->problems->search( {
            id => $id,
            state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
            photo => { '!=', undef },
        } );
    }

    $c->detach( 'no_photo' ) unless $item;

    $c->detach( 'no_photo' ) unless $c->cobrand->allow_photo_display($item, $photo_number); # Should only be for reports, not updates

    my $problem = $is_update ? $item->problem : $item;
    if ($problem->non_public) {
        my $body_ids = $problem->bodies_str_ids;
        # Check permission
        $c->detach('no_photo') unless $c->user_exists;
        $c->detach('no_photo') unless $c->user->is_superuser
            || $c->user->id == $problem->user->id
            || $c->user->has_permission_to('report_inspect', $body_ids)
            || $c->user->has_permission_to('report_mark_private', $body_ids);
    }

    my $photo;
    $photo = $item->get_photoset
        ->get_image_data( num => $photo_number, size => $size, default => $c->cobrand->default_photo_resize )
        or $c->detach( 'no_photo' );

    $c->forward( 'output', [ $photo ] );
}

sub output : Private {
    my ( $self, $c, $photo ) = @_;

    $c->res->content_type( $photo->{content_type} );
    $c->res->body( $photo->{data} );
}

sub no_photo : Private {
    my ( $self, $c ) = @_;
    $c->detach( '/page_error_404_not_found', [ 'No photo' ] );
}

sub upload : Local {
    my ( $self, $c ) = @_;
    my @items = (
        ( map {
            /^photo/ ? # photo, photo1, photo2 etc.
                ($c->req->upload($_)) : ()
        } sort $c->req->upload),
    );
    my $photoset = FixMyStreet::App::Model::PhotoSet->new({
        c => $c,
        data_items => \@items,
    });
    my $fileid = try {
        $photoset->data;
    } catch {
        $c->log->debug("Photo upload failed.");
        $c->stash->{photo_error} = _("Photo upload failed.");
        return undef;
    };
    my $out;
    if ($c->stash->{photo_error} || !$fileid) {
        $c->res->status(500);
        $out = { error => $c->stash->{photo_error} || _('Unknown error') };
    } else {
        $out = { id => $fileid };
    }

    if ($c->get_param('get_latlon') && $c->stash->{photo_gps}) {
        $out = {
            %$out,
            %{ $c->stash->{photo_gps} },
        };
    }

    if ($c->get_param('start_report') && $c->stash->{photo_gps}) {
        my $url = $c->uri_for( "/report/new", {
            lat => $c->stash->{photo_gps}->{lat},
            lon => $c->stash->{photo_gps}->{lon},
            photo_id => $fileid,
        } );
        return $c->res->redirect($url);
    }

    $c->res->content_type('application/json; charset=utf-8');
    $c->res->body(encode_json($out));
}

=head2 process_photo

Handle the photo - either checking and storing it after an upload or retrieving
it from the cache.

Store any error message onto 'photo_error' in stash.
=cut

sub process_photo : Private {
    my ( $self, $c ) = @_;

    return
         $c->forward('process_photo_upload_or_cache')
      || $c->forward('process_photo_required')
      || 1;    # always return true
}

sub process_photo_upload_or_cache : Private {
    my ( $self, $c ) = @_;

    my $fileid_field
        = $c->stash->{photo_upload_fileid_field} || 'upload_fileid';

    # Use bulky collection photo data, if there is any
    my @items = @{ $c->stash->{bulky_photo_data} // [] };

    if ( !@items ) {
        my $photo_prefix = $c->stash->{photo_upload_prefix} || 'photo';
        @items        = (
            (   map {
                    /^$photo_prefix/
                        ?    # photo, photo1, photo2 etc.
                        ( $c->req->upload($_) )
                        : ()
                } sort $c->req->upload
            ),
            grep {$_} split /,/,
            ( $c->get_param($fileid_field) || '' )
        );
    }

    my $photoset = FixMyStreet::App::Model::PhotoSet->new({
        c => $c,
        data_items => \@items,
    });

    my $fileid = $photoset->data;

    $c->stash->{$fileid_field} = $fileid or return;
    return 1;
}

=head2 process_photo_required

Checks that a report has a photo attached if any of its Contacts
require it (by setting extra->photo_required == 1). Puts an error in
photo_error on the stash if it's required and missing, otherwise returns
true.

(Note that as we have reached this action, we *know* that the photo
is missing, otherwise it would have already been handled.)

=cut

sub process_photo_required : Private {
    my ( $self, $c ) = @_;

    # load the report
    my $report = $c->stash->{report} or return 1; # don't check photo for updates
    my $bodies = $c->stash->{bodies};

    my @contacts = $c->       #
      model('DB::Contact')    #
      ->not_deleted           #
      ->search(
        {
            body_id => [ keys %$bodies ],
            category => $report->category
        }
      )->all;
      foreach my $contact ( @contacts ) {
          if ( $contact->get_extra_metadata('photo_required') ) {
              $c->stash->{photo_error} = _("Photo is required.");
              return;
          }
      }

    return 1;
}


=head1 AUTHOR

Struan Donald

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
