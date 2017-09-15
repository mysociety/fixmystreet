package FixMyStreet::DB::ResultSet::User;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

use Moo;

# The database has a partial unique index on email (when email_verified is
# true), and phone (when phone_verified is true). In the code, we can only
# say these are fully unique indices, which they aren't, as there could be
# multiple identical unverified phone numbers.
#
# We assume that any and all calls to find (also called using find_or_new,
# find_or_create, or update_or_new/create) are to look up verified entries
# only (it would make no sense to find() a non-unique entry). Therefore we
# help the code along by specifying the most appropriate key to use, given
# the data provided, and setting the appropriate verified boolean.

around find => sub {
    my ($orig, $self) = (shift, shift);
    # If there's already a key, assume caller knows what they're doing
    if (ref $_[0] eq 'HASH' && !$_[1]->{key}) {
        if ($_[0]->{id}) {
            $_[1]->{key} = 'primary';
        } elsif (exists $_[0]->{email} && exists $_[0]->{phone}) {
            # If there's both email and phone, caller must also have specified
            # a verified boolean so that we know what we're looking for
            if (!$_[0]->{email_verified} && !$_[0]->{phone_verified}) {
                die "Cannot perform a User find() with both email and phone and no verified";
            }
        } elsif (exists $_[0]->{email}) {
            $_[0]->{email_verified} = 1;
            $_[1]->{key} = 'users_email_verified_key';
        } elsif (exists $_[0]->{phone}) {
            $_[0]->{phone_verified} = 1;
            $_[1]->{key} = 'users_phone_verified_key';
        }
    }
    $self->$orig(@_);
};

1;
