
package BarnetElements::Z_CRM_SERVICE_ORDER_CREATE;
use strict;
use warnings;

{ # BLOCK to scope variables

sub get_xmlns { 'urn:sap-com:document:sap:rfc:functions' }

__PACKAGE__->__set_name('Z_CRM_SERVICE_ORDER_CREATE');
__PACKAGE__->__set_nillable();
__PACKAGE__->__set_minOccurs();
__PACKAGE__->__set_maxOccurs();
__PACKAGE__->__set_ref();

use base qw(
    SOAP::WSDL::XSD::Typelib::Element
    SOAP::WSDL::XSD::Typelib::ComplexType
);

our $XML_ATTRIBUTE_CLASS;
undef $XML_ATTRIBUTE_CLASS;

sub __get_attr_class {
    return $XML_ATTRIBUTE_CLASS;
}

use Class::Std::Fast::Storable constructor => 'none';
use base qw(SOAP::WSDL::XSD::Typelib::ComplexType);

Class::Std::initialize();

{ # BLOCK to scope variables

my %ET_RETURN_of :ATTR(:get<ET_RETURN>);
my %IT_PROBLEM_DESC_of :ATTR(:get<IT_PROBLEM_DESC>);
my %IV_CUST_EMAIL_of :ATTR(:get<IV_CUST_EMAIL>);
my %IV_CUST_NAME_of :ATTR(:get<IV_CUST_NAME>);
my %IV_KBID_of :ATTR(:get<IV_KBID>);
my %IV_PROBLEM_ID_of :ATTR(:get<IV_PROBLEM_ID>);
my %IV_PROBLEM_LOC_of :ATTR(:get<IV_PROBLEM_LOC>);
my %IV_PROBLEM_SUB_of :ATTR(:get<IV_PROBLEM_SUB>);

__PACKAGE__->_factory(
    [ qw(        ET_RETURN
        IT_PROBLEM_DESC
        IV_CUST_EMAIL
        IV_CUST_NAME
        IV_KBID
        IV_PROBLEM_ID
        IV_PROBLEM_LOC
        IV_PROBLEM_SUB

    ) ],
    {
        'ET_RETURN' => \%ET_RETURN_of,
        'IT_PROBLEM_DESC' => \%IT_PROBLEM_DESC_of,
        'IV_CUST_EMAIL' => \%IV_CUST_EMAIL_of,
        'IV_CUST_NAME' => \%IV_CUST_NAME_of,
        'IV_KBID' => \%IV_KBID_of,
        'IV_PROBLEM_ID' => \%IV_PROBLEM_ID_of,
        'IV_PROBLEM_LOC' => \%IV_PROBLEM_LOC_of,
        'IV_PROBLEM_SUB' => \%IV_PROBLEM_SUB_of,
    },
    {
        'ET_RETURN' => 'BarnetTypes::TABLE_OF_BAPIRET2',
        'IT_PROBLEM_DESC' => 'BarnetTypes::TABLE_OF_CRMT_SERVICE_REQUEST_TEXT',
        'IV_CUST_EMAIL' => 'BarnetTypes::char241',
        'IV_CUST_NAME' => 'BarnetTypes::char50',
        'IV_KBID' => 'BarnetTypes::char50',
        'IV_PROBLEM_ID' => 'BarnetTypes::char35',
        'IV_PROBLEM_LOC' => 'BarnetTypes::BAPI_TTET_ADDRESS_COM',
        'IV_PROBLEM_SUB' => 'BarnetTypes::char40',
    },
    {

        'ET_RETURN' => 'ET_RETURN',
        'IT_PROBLEM_DESC' => 'IT_PROBLEM_DESC',
        'IV_CUST_EMAIL' => 'IV_CUST_EMAIL',
        'IV_CUST_NAME' => 'IV_CUST_NAME',
        'IV_KBID' => 'IV_KBID',
        'IV_PROBLEM_ID' => 'IV_PROBLEM_ID',
        'IV_PROBLEM_LOC' => 'IV_PROBLEM_LOC',
        'IV_PROBLEM_SUB' => 'IV_PROBLEM_SUB',
    }
);

} # end BLOCK






} # end of BLOCK



1;


=pod

=head1 NAME

BarnetElements::Z_CRM_SERVICE_ORDER_CREATE

=head1 DESCRIPTION

Perl data type class for the XML Schema defined element
Z_CRM_SERVICE_ORDER_CREATE from the namespace urn:sap-com:document:sap:rfc:functions.







=head1 PROPERTIES

The following properties may be accessed using get_PROPERTY / set_PROPERTY
methods:

=over

=item * ET_RETURN

 $element->set_ET_RETURN($data);
 $element->get_ET_RETURN();




=item * IT_PROBLEM_DESC

 $element->set_IT_PROBLEM_DESC($data);
 $element->get_IT_PROBLEM_DESC();




=item * IV_CUST_EMAIL

 $element->set_IV_CUST_EMAIL($data);
 $element->get_IV_CUST_EMAIL();




=item * IV_CUST_NAME

 $element->set_IV_CUST_NAME($data);
 $element->get_IV_CUST_NAME();




=item * IV_KBID

 $element->set_IV_KBID($data);
 $element->get_IV_KBID();




=item * IV_PROBLEM_ID

 $element->set_IV_PROBLEM_ID($data);
 $element->get_IV_PROBLEM_ID();




=item * IV_PROBLEM_LOC

 $element->set_IV_PROBLEM_LOC($data);
 $element->get_IV_PROBLEM_LOC();




=item * IV_PROBLEM_SUB

 $element->set_IV_PROBLEM_SUB($data);
 $element->get_IV_PROBLEM_SUB();





=back


=head1 METHODS

=head2 new

 my $element = BarnetElements::Z_CRM_SERVICE_ORDER_CREATE->new($data);

Constructor. The following data structure may be passed to new():

 {
   ET_RETURN =>  { # BarnetTypes::TABLE_OF_BAPIRET2
     item =>  { # BarnetTypes::BAPIRET2
       TYPE => $some_value, # char1
       ID => $some_value, # char20
       NUMBER => $some_value, # numeric3
       MESSAGE => $some_value, # char220
       LOG_NO => $some_value, # char20
       LOG_MSG_NO => $some_value, # numeric6
       MESSAGE_V1 => $some_value, # char50
       MESSAGE_V2 => $some_value, # char50
       MESSAGE_V3 => $some_value, # char50
       MESSAGE_V4 => $some_value, # char50
       PARAMETER => $some_value, # char32
       ROW =>  $some_value, # int
       FIELD => $some_value, # char30
       SYSTEM => $some_value, # char10
     },
   },
   IT_PROBLEM_DESC =>  { # BarnetTypes::TABLE_OF_CRMT_SERVICE_REQUEST_TEXT
     item =>  { # BarnetTypes::CRMT_SERVICE_REQUEST_TEXT
       TEXT_LINE => $some_value, # char132
     },
   },
   IV_CUST_EMAIL => $some_value, # char241
   IV_CUST_NAME => $some_value, # char50
   IV_KBID => $some_value, # char50
   IV_PROBLEM_ID => $some_value, # char35
   IV_PROBLEM_LOC =>  { # BarnetTypes::BAPI_TTET_ADDRESS_COM
     COUNTRY2 => $some_value, # char2
     REGION => $some_value, # char3
     COUNTY => $some_value, # char30
     CITY => $some_value, # char30
     POSTALCODE => $some_value, # char10
     STREET => $some_value, # char30
     STREETNUMBER => $some_value, # char5
     GEOCODE => $some_value, # char32
   },
   IV_PROBLEM_SUB => $some_value, # char40
 },

=head1 AUTHOR

Generated by SOAP::WSDL

=cut

