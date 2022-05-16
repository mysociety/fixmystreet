package t::Mock::Static;

use Path::Tiny;
use Web::Simple;

my $sample_file = path(__FILE__)->parent->parent->child("app/controller/sample.jpg");
my $sample_photo = $sample_file->slurp_raw;
my $sample_gif = path(__FILE__)->parent->parent->child("app/helpers/grey.gif");
my $sample_gif_data = $sample_gif->slurp_raw;

sub dispatch_request {
    my $self = shift;

    sub (GET + /image.jpeg) {
        my ($self) = @_;
        return [ 200, [ 'Content-Type' => 'image/jpeg' ], [ $sample_photo ] ];
    },

    sub (GET + /image.gif) {
        my ($self) = @_;
        return [ 200, [ 'Content-Type' => 'image/gif' ], [ $sample_gif_data ] ];
    },
}

__PACKAGE__->run_if_script;
