package FixMyStreet::App::View::Web;
use base 'Catalyst::View::TT';

use strict;
use warnings;

use Digest::MD5;
use FixMyStreet;
use FixMyStreet::Template;
use FixMyStreet::Template::SafeString;
use Utils;

__PACKAGE__->config(
    CLASS => 'FixMyStreet::Template',
    TEMPLATE_EXTENSION => '.html',
    INCLUDE_PATH       => [
        FixMyStreet->path_to( 'templates', 'web', 'base' ),
    ],
    render_die     => 1,
    expose_methods => [
        'tprintf', 'prettify_dt',
        'version', 'decode',
        'prettify_state',
        'mark_safe',
    ],
    FILTERS => {
        add_links => \&add_links,
        escape_js => \&escape_js,
        staff_html_markup => [ \&staff_html_markup_factory, 1 ],
    },
    COMPILE_EXT => '.ttc',
    STAT_TTL    => FixMyStreet->config('STAGING_SITE') ? 1 : 86400,
);

=head1 NAME

FixMyStreet::App::View::Web - TT View for FixMyStreet::App

=head1 DESCRIPTION

TT View for FixMyStreet::App.

=cut

# Override parent function so that errors are only logged once.
sub _rendering_error {
    my ($self, $c, $err) = @_;
    my $error = qq/Couldn't render template "$err"/;
    # $c->log->error($error);
    $c->error($error);
    return 0;
}

=head2 tprintf

    [% tprintf( 'foo %s bar', 'insert' ) %]

sprintf (different name to avoid clash)

=cut

sub tprintf {
    my ( $self, $c, $format, @args ) = @_;
    @args = @{$args[0]} if ref $args[0] eq 'ARRAY';
    #$format = $format->plain if UNIVERSAL::isa($format, 'Template::HTML::Variable');
    my $s = sprintf $format, @args;
    return FixMyStreet::Template::SafeString->new($s);
}

sub mark_safe {
    my ($self, $c, $s) = @_;
    $s = $s->plain if UNIVERSAL::isa($s, 'FixMyStreet::Template::Variable');
    return FixMyStreet::Template::SafeString->new($s);
}

=head2 Utils::prettify_dt

    [% pretty = prettify_dt( $dt, $short_bool ) %]

Return a pretty version of the DateTime object.

    $short_bool = 1;     # 16:02, 29 Mar 2011
    $short_bool = 0;     # 16:02, Tuesday 29 March 2011

=cut

sub prettify_dt {
    my ( $self, $c, $epoch, $short_bool ) = @_;
    return Utils::prettify_dt( $epoch, $short_bool );
}

=head2 add_links

    [% text | add_links | html_para %]

Add some links to some text (and thus HTML-escapes the other text).

=cut

sub add_links {
    my $text = shift;
    return FixMyStreet::Template::add_links($text);
}

=head2 staff_html_markup_factory

This returns a function that processes the text body of an update, applying
HTML sanitization and markdown-style italics if it was made by a staff user.

Pass in the update extra, so we can determine if it was made by a staff user.

=cut

sub staff_html_markup_factory {
    my ($c, $extra) = @_;

    my $staff = $extra->{is_superuser} || $extra->{is_body_user};

    return sub {
        my $text = shift;
        return FixMyStreet::Template::_staff_html_markup($text, $staff);
    }
}

=head2 escape_js

Used to escape strings that are going to be put inside JavaScript.

=cut

sub escape_js {
    my $text = shift;
    my %lookup = (
        '\\' => 'u005c',
        '"'  => 'u0022',
        "'"  => 'u0027',
        '<'  => 'u003c',
        '>'  => 'u003e',
    );
    $text =~ s/([\\"'<>])/\\$lookup{$1}/g;

    $text =~ s/(?:\r\n|\n|\r)/\\n/g; # replace newlines

    return $text;
}

my %version_hash;
sub version {
    my ( $self, $c, $file, $url ) = @_;
    $url ||= $file;
    _version_get_details($file);
    if ($version_hash{$file} && $file =~ /\.js$/) {
        # See if there's an auto.min.js version and use that instead if there is
        (my $file_min = $file) =~ s/\.js$/.auto.min.js/;
        _version_get_details($file_min);
        $url = $file = $file_min if $version_hash{$file_min}{mtime} >= $version_hash{$file}{mtime};
    }
    my $admin = $self->template->context->stash->{admin} ? FixMyStreet->config('ADMIN_BASE_URL') : '';
    return "$admin$url?$version_hash{$file}{digest}";
}

sub _version_get_details {
    my $file = shift;
    return if $version_hash{$file} && !FixMyStreet->config('STAGING_SITE');
    my $path = FixMyStreet->path_to('web', $file);
    my ($digest, $mtime);
    if (open (my $fh, '<', $path)) {
        binmode $fh;
        $digest = Digest::MD5->new->addfile($fh)->hexdigest;
        $mtime = ( stat( $path ) )[9];
        close $fh;
    }
    $version_hash{$file} = {
        digest => substr($digest || '', 0, 12),
        mtime => $mtime || 0,
    };
}

sub decode {
    my ( $self, $c, $text ) = @_;
    utf8::decode($text) unless utf8::is_utf8($text);
    return $text;
}

sub prettify_state {
    my ($self, $c, $text, $single_fixed) = @_;

    return FixMyStreet::DB->resultset("State")->display($text, $single_fixed);
}

1;

