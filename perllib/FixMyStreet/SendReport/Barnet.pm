package FixMyStreet::SendReport::Barnet;

use Moose;

BEGIN { extends 'FixMyStreet::SendReport'; }

use Encode;
use Utils;
use mySociety::Config;
use mySociety::Web qw(ent);

# specific council numbers
use constant COUNCIL_ID_BARNET     => 2489;
use constant MAX_LINE_LENGTH       => 132;

sub construct_message {
    my %h = @_;
    my $message = <<EOF;
Subject: $h{title}

Details: $h{detail}

$h{fuzzy}, or to provide an update on the problem, please visit the following link:

$h{url}

$h{closest_address}
EOF
}


sub send {
    my ( $self, $row, $h ) = @_;

    my %h = %$h;

    $h{message} = construct_message(%h);

    my $return = 1;
    my $err_msg = "";

    my $default_kbid = 14; # This is the default, "Street Scene"
    my $kbid = sprintf( "%050d",  Utils::barnet_categories()->{$h{category}} || $default_kbid);

    my $geo_code = "$h{easting} $h{northing}"; 

    require BarnetInterfaces::service::ZLBB_SERVICE_ORDER;
    my $interface = BarnetInterfaces::service::ZLBB_SERVICE_ORDER->new();
    
    my ($nearest_postcode, $nearest_street) = ('', '');
    for ($h{closest_address}) {
        $nearest_postcode = sprintf("%-10s", $1) if /Nearest postcode [^:]+: ((\w{1,4}\s?\w+|\w+))/;
        # use partial postcode or comma as delimiter, strip leading number (possible letter 221B) off too
        #    "99 Foo Street, London N11 1XX" becomes Foo Street
        #    "99 Foo Street N11 1XX" becomes Foo Street
        $nearest_street = $1 if /Nearest road [^:]+: (?:\d+\w? )?(.*?)(\b[A-Z]+\d|,|$)/m;
    }
    my $postcode = mySociety::PostcodeUtil::is_valid_postcode($h{query})
        ? $h{query} : $nearest_postcode; # use given postcode if available
    
    # note: endpoint can be of form 'https://username:password@url'
    my $body = FixMyStreet::App->model("DB::Body")->search( { 'body_areas.area_id' => COUNCIL_ID_BARNET }, { join => "body_areas" } )->first;
    if ($body and $body->endpoint) {
        $interface->set_proxy($body->endpoint);
        # Barnet web service doesn't like namespaces in the elements so use a prefix
        $interface->set_prefix('urn');
        # uncomment these lines to print XML that will be sent rather
        # than connecting to the endpoint
        #$interface->outputxml(1);
        #$interface->no_dispatch(1);
    } else {
        die "Barnet webservice FAIL: looks like you're missing some config data: no endpoint (URL) found for area ID " . COUNCIL_ID_BARNET;
    }
    
    eval {    
        my $result = $interface->Z_CRM_SERVICE_ORDER_CREATE( {
            ET_RETURN =>  { # ignored by server
              item =>  {
                  TYPE => "", ID => "", NUMBER => "", MESSAGE => "", LOG_NO => "", LOG_MSG_NO => "", 
                  MESSAGE_V1 => "", MESSAGE_V2 => "", MESSAGE_V3 => "", MESSAGE_V4 => "", PARAMETER => "", 
                  ROW =>  "", FIELD => "", SYSTEM => "",
                },
            },
            IT_PROBLEM_DESC =>  { # MyTypes::TABLE_OF_CRMT_SERVICE_REQUEST_TEXT
              item =>  [ # MyTypes::CRMT_SERVICE_REQUEST_TEXT
                map { { TEXT_LINE => $_ } } split_text_with_entities(ent(encode_utf8($h{message})), 132) # char132
              ],
            },
            IV_CUST_EMAIL => truncate_string_with_entities(ent(encode_utf8($h{email})), 241), # char241
            IV_CUST_NAME  => truncate_string_with_entities(ent(encode_utf8($h{name})),   50), # char50
            IV_KBID => $kbid,        # char50
            IV_PROBLEM_ID => $h{id}, # char35
            IV_PROBLEM_LOC =>  {     # MyTypes::BAPI_TTET_ADDRESS_COM
              COUNTRY2 => 'GB',      # char2
              REGION => "",          # char3
              COUNTY => "",          # char30
              CITY => "",            # char30
              POSTALCODE => $postcode,   # char10
              STREET => truncate_string_with_entities(ent(encode_utf8($nearest_street)), 30), # char30
              STREETNUMBER => "",    # char5
              GEOCODE => $geo_code,  # char32
            },
            IV_PROBLEM_SUB => truncate_string_with_entities(ent(encode_utf8($h{title})), 40), # char40
          },
        );
        if ($result) {
            # currently not using this: get_EV_ORDER_GUID (maybe that's the customer number in the CRM)
            if (my $barnet_id = $result->get_EV_ORDER_NO()) {
                $row->external_id( $barnet_id );
                $row->external_body( 'Barnet Borough Council' ); # better to use $row->body()?
                $row->send_method_used('barnet');
                $return = 0;
            } else {
                my @returned_items = split  /<item[^>]*>/, $result->get_ET_RETURN;
                my @messages = ();
                foreach my $item (@returned_items) {
                    if ($item=~/<MESSAGE [^>]*>\s*(\S.*?)<\/MESSAGE>/) { # if there's a non-null MESSAGE in there, grab it
                        push @messages, $1;  # best stab at extracting useful error message back from convoluted response
                    }
                }
                push @messages, "service returned no external id" unless @messages;
                $err_msg = "Failed (problem id $h{id}): " . join(" \n ", @messages);
            }
        } else {
            my %fault = (
                    'code' =>  $result->get_faultcode(),
                    'actor' =>  $result->get_faultactor(),
                    'string' =>  $result->get_faultstring(),
                    'detail' =>  $result->get_detail(), # possibly only contains debug info
                );
            foreach (keys %fault) {
                $fault{$_}="" unless defined $fault{$_};
                $fault{$_}=~s/^\s*|\s*$//g;
            }
            $fault{actor}&&=" (actor: $fault{actor})";
            $fault{'detail'} &&= "\n" . $fault{'detail'};
            $err_msg = "Failed (problem id $h{id}): Fault $fault{code}$fault{actor}\n$fault{string}$fault{detail}";
        }

    };
    if ($err_msg) {
        # for timeouts, we can tidy the message a wee bit (i.e. strip the 'error deserializing...' message)
        $err_msg=~s/(?:Error deserializing message:.*)(Can't connect to [a-zA-Z0-9.:]+\s*\(Connection timed out\)).*/$1/s;
        print "$err_msg\n";
    }
    if ($@) {
        my $e = shift;
        print "Caught an error: $@\n"; 
    }
    if ( $return ) {
        $self->error( "Error sending to Barnet: $err_msg" );
    }
    $self->success( !$return );
    return $return;
}

# for barnet webservice: max-length fields require truncate and split

# truncate_string_with_entities
# args:    text to truncate
#          max number of chars
# returns: string truncated
# Note: must not partially truncate an entity (e.g., &amp;)
sub truncate_string_with_entities {
    my ($str, $max_len) = @_;
    my $retVal = "";
    foreach my $chunk  (split /(\&(?:\#\d+|\w+);)/, $str) {
        if ($chunk=~/^\&(\#\d+|\w+);$/){
            my $next = $retVal.$chunk;
            last if length $next > $max_len;
            $retVal=$next
        } else {
            $retVal.=$chunk;
            if (length $retVal > $max_len) {
                $retVal = substr($retVal, 0, $max_len);
                last
            }
        } 
    }
    return $retVal
}

# split_text_with_entities into lines
# args:    text to be broken into lines
#          max length (option: uses constant MAX_LINE_LENGTH)
# returns: array of lines
# Must not to split an entity (e.g., &amp;)
# Not worrying about hyphenating here, since a word is only ever split if 
# it's longer than the whole line, which is uncommon in genuine problem reports
sub split_text_with_entities {
    my ($text, $max_line_length) = @_;
    $max_line_length ||= MAX_LINE_LENGTH;
    my @lines;
    foreach my $line (split "\n", $text) {
        while (length $line > $max_line_length) {
            if (! ($line =~ s/^(.{1,$max_line_length})\s//                 # break on a space
                or $line =~ s/^(.{1,$max_line_length})(\&(\#\d+|\w+);)/$2/ # break before an entity
                or $line =~ s/(.{$max_line_length})//)) {                  # break the word ruthlessly
                $line =~ s/(.*)//; # otherwise gobble whole line (which is now shorter than max length)
            }
            push @lines, $1;
        }
        push @lines, $line;
    }
    return @lines;
}

1;
