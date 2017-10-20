package FixMyStreet::App::Controller::About;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::About - Catalyst Controller

=head1 DESCRIPTION

About pages Catalyst Controller.

=head1 METHODS

=cut

my %found;

sub page : Path("/about") : Args(1) {
    my ( $self, $c, $page ) = @_;
    my $template = $c->forward('find_template');
    $c->detach('/page_error_404_not_found', []) unless $template;
    $c->stash->{template} = $template;
    $c->cobrand->call_hook('about_hook');
}

sub index : Path("/about") : Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('page', [ 'about' ]);
}

# We have multiple possibilities to try, and we want to cache where we find it
sub find_template : Private {
    my ( $self, $c, $page ) = @_;

    my $lang_code = $c->stash->{lang_code};

    return $found{$lang_code}{$page} if !FixMyStreet->config('STAGING_SITE') &&
                                        exists $found{$lang_code}{$page};

    foreach my $dir_templates (@{$c->stash->{additional_template_paths}}, @{$c->view('Web')->paths}) {
        foreach my $dir_static (static_dirs($page, $dir_templates)) {
            foreach my $file ("$page-$lang_code.html", "$page.html") {
                if (-e "$dir_templates/$dir_static/$file") {
                    $found{$lang_code}{$page} = "$dir_static/$file";
                    return $found{$lang_code}{$page};
                }
            }
        }
    }
    # Cache that the page does not exist, so we don't look next time
    $found{$lang_code}{$page} = undef;
    return $found{$lang_code}{$page};
}

sub static_dirs {
    my ($page, $dir_templates) = @_;
    my @v = ("about");
    # If legacy directories exist, check for templates there too;
    # The FAQ page used to be in its own directory
    push @v, "static" if -d "$dir_templates/static";
    push @v, "faq" if -d "$dir_templates/faq" && $page =~ /faq/;
    return @v;
}

__PACKAGE__->meta->make_immutable;

1;
