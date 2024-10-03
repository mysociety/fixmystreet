=head1 NAME

BexleyAddresses - handles address lookup for Bexley WasteWorks.

=head1 SYNOPSIS

Bexley provide us with a CSV file of LLPG (Local Land and Property Gazetteer) data which we pull into an SQLite database file.

This is done by running the CSV on C<bin/bexley/make-bexley-ww-postcode-db>.

That script shows the setup of the database in more detail, but to explain briefly, there are three tables:

=over 4

=item * postcodes

Stores postcode, UPRN, USRN, and address portions (e.g. house number and name) for each property (properties are uniquely identified by their UPRN).

Also stores 'blpu_class'; if it is 'P' or 'PP', it means the property is a
'parent shell' and so should not be offered as a selectable address.

=item * street_descriptors

Stores address data (e.g. street & town name) for each USRN (street identifier)

=item * child_uprns

Captures mapping between parent and child properties (e.g. if a building contains multiple flats, the building is the parent, the children are the flats).

If a property has a parent, the parent's address details ('Secondary
Addressable Object' or sao_* fields) are included in the address.

=back

=cut

package BexleyAddresses;

use strict;
use warnings;

use DBI;
use FixMyStreet;
use mySociety::PostcodeUtil;

=head2 database_file

Database is in C<../data/bexley-ww-postcodes.sqlite>

=cut

sub database_file {
    FixMyStreet->path_to('../data/bexley-ww-postcodes.sqlite');
}

sub connect_db {
    die $! unless -e database_file();

    return DBI->connect( 'dbi:SQLite:dbname=' . database_file(),
        undef, undef );
}

=head2 addresses_for_postcode

We only fetch child addresses. These are displayed in a dropdown after user
has input a postcode.

=cut

sub addresses_for_postcode {
    my $postcode = shift;

    my $db = connect_db() or return [];

    # Remove whitespaces, make sure uppercase
    $postcode =~ s/ //g;
    $postcode = uc $postcode;

    my $address_fields = _address_fields();

    # If blpu_class is 'P' or 'PP', it means the property is a
    # 'parent shell' and so should not be offered as an option
    my $addresses = $db->selectall_arrayref(
        <<"SQL",
   SELECT p.uprn uprn,
          p.usrn usrn,
          $address_fields
     FROM postcodes p
     JOIN street_descriptors sd
       ON sd.usrn = p.usrn
     LEFT OUTER JOIN child_uprns cu
       ON cu.uprn = p.uprn
    WHERE p.postcode = ?
      AND p.blpu_class != 'P'
      AND p.blpu_class != 'PP'
SQL
        { Slice => {} },
        $postcode,
    );

    return [ sort _sort_addresses @$addresses ];
}

sub usrn_for_uprn {
    my $uprn = shift;

    my $db = connect_db() or return '';

    return ( $db->selectrow_hashref(
        <<"SQL",
  SELECT usrn
    FROM postcodes
   WHERE uprn = ?
SQL
        { Slice => {} },
        $uprn,
    ) // {} )->{usrn};
}

sub address_for_uprn {
    my $uprn = shift;

    die $! unless -e database_file();

    my $db = connect_db() or return '';

    my $address_fields = _address_fields();

    my $row = $db->selectrow_hashref(
        <<"SQL",
   SELECT postcode,
          $address_fields
     FROM postcodes p
     JOIN street_descriptors sd
       ON sd.usrn = p.usrn
     LEFT OUTER JOIN child_uprns cu
       ON cu.uprn = p.uprn
    WHERE p.uprn = ?
SQL
        undef,
        $uprn,
    );

    return $row ? build_address_string($row) : '';
}

sub build_address_string {
    my $row = shift;

    my $sao;
    if ( $row->{parent_uprn} ) {
        $sao = _join_extended(
            ', ',
            $row->{sao_text},
            _join_extended(
                '-',
                _join_extended(
                    '', $row->{sao_start_number},
                    $row->{sao_start_suffix},
                ),
                _join_extended(
                    '',
                    $row->{sao_end_number},
                    $row->{sao_end_suffix},
                ),
            ),
        );
    }

    my $pao = _join_extended(
        ', ',
        $row->{pao_text},
        _join_extended(
            '-',
            _join_extended(
                '',
                $row->{pao_start_number},
                $row->{pao_start_suffix},
            ),
            _join_extended(
                '',
                $row->{pao_end_number},
                $row->{pao_end_suffix},
            ),
        ),
    );

    return _join_extended(
        ', ',
        $sao,
        _join_extended( ' ', $pao, $row->{street_descriptor} ),
        $row->{locality_name},
        $row->{town_name},
        mySociety::PostcodeUtil::canonicalise_postcode( $row->{postcode} ),
    );
}

# Only joins strings that are true / non-empty
sub _join_extended {
    my ( $sep, @strings ) = @_;

    my @strings_true_only;
    for (@strings) {
        push @strings_true_only, $_ if $_;
    }

    return join $sep, @strings_true_only;
}

sub _sort_addresses {
    ( $a->{pao_start_number} || 0 ) <=> ( $b->{pao_start_number} || 0 )
    or
    ( $a->{pao_start_suffix} || '' ) cmp ( $b->{pao_start_suffix} || '' )
    or
    ( $a->{pao_text} || '' ) cmp ( $b->{pao_text} || '' )
    or
    ( $a->{sao_start_number} || 0 ) <=> ( $b->{sao_start_number} || 0 )
    or
    ( $a->{sao_start_suffix} || '' ) cmp ( $b->{sao_start_suffix} || '' )
    or
    ( $a->{sao_text} || '' ) cmp ( $b->{sao_text} || '' )
}

# Fields needed to build an address string
sub _address_fields {
    return <<SQL;
        pao_start_number,
        pao_start_suffix,
        pao_end_number,
        pao_end_suffix,
        pao_text,

        sao_start_number,
        sao_start_suffix,
        sao_end_number,
        sao_end_suffix,
        sao_text,

        street_descriptor,
        locality_name,
        town_name,

        parent_uprn
SQL
}

1;
