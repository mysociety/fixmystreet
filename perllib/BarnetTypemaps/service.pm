
package BarnetTypemaps::service;
use strict;
use warnings;

our $typemap_1 = {
               'Z_CRM_SERVICE_ORDER_CREATEResponse/EV_ORDER_NO' => 'BarnetTypes::char10',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_PROBLEM_LOC/GEOCODE' => 'BarnetTypes::char32',
               'Fault/faultcode' => 'SOAP::WSDL::XSD::Typelib::Builtin::anyURI',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_PROBLEM_LOC/COUNTRY2' => 'BarnetTypes::char2',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/NUMBER' => 'BarnetTypes::numeric3',
               'Z_CRM_SERVICE_ORDER_CREATE/IT_PROBLEM_DESC/item' => 'BarnetTypes::CRMT_SERVICE_REQUEST_TEXT',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/MESSAGE_V1' => 'BarnetTypes::char50',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_PROBLEM_LOC/POSTALCODE' => 'BarnetTypes::char10',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/LOG_NO' => 'BarnetTypes::char20',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/MESSAGE_V2' => 'BarnetTypes::char50',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/MESSAGE_V3' => 'BarnetTypes::char50',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_PROBLEM_SUB' => 'BarnetTypes::char40',
               'Z_CRM_SERVICE_ORDER_CREATE/IT_PROBLEM_DESC/item/TEXT_LINE' => 'BarnetTypes::char132',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/LOG_NO' => 'BarnetTypes::char20',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN' => 'BarnetTypes::TABLE_OF_BAPIRET2',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/ROW' => 'SOAP::WSDL::XSD::Typelib::Builtin::int',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/IT_PROBLEM_DESC/item' => 'BarnetTypes::CRMT_SERVICE_REQUEST_TEXT',
               'Fault/faultstring' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/PARAMETER' => 'BarnetTypes::char32',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item' => 'BarnetTypes::BAPIRET2',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_CUST_NAME' => 'BarnetTypes::char50',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/MESSAGE_V2' => 'BarnetTypes::char50',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/ROW' => 'SOAP::WSDL::XSD::Typelib::Builtin::int',
               'Fault/detail' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
               'Z_CRM_SERVICE_ORDER_CREATE.Exception/Message/ID' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/IT_PROBLEM_DESC' => 'BarnetTypes::TABLE_OF_CRMT_SERVICE_REQUEST_TEXT',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/NUMBER' => 'BarnetTypes::numeric3',
               'Z_CRM_SERVICE_ORDER_CREATEResponse' => 'BarnetElements::Z_CRM_SERVICE_ORDER_CREATEResponse',
               'Z_CRM_SERVICE_ORDER_CREATE.Exception/Text' => 'SOAP::WSDL::XSD::Typelib::Builtin::string',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/MESSAGE_V1' => 'BarnetTypes::char50',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/PARAMETER' => 'BarnetTypes::char32',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/MESSAGE' => 'BarnetTypes::char220',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/TYPE' => 'BarnetTypes::char1',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/MESSAGE' => 'BarnetTypes::char220',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_PROBLEM_LOC' => 'BarnetTypes::BAPI_TTET_ADDRESS_COM',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/TYPE' => 'BarnetTypes::char1',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_CUST_EMAIL' => 'BarnetTypes::char241',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/FIELD' => 'BarnetTypes::char30',
               'Z_CRM_SERVICE_ORDER_CREATE.Exception/Name' => 'BarnetTypes::Z_CRM_SERVICE_ORDER_CREATE::RfcExceptions',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/IT_PROBLEM_DESC/item/TEXT_LINE' => 'BarnetTypes::char132',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/ID' => 'BarnetTypes::char20',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/EV_ORDER_GUID' => 'BarnetTypes::char32',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/SYSTEM' => 'BarnetTypes::char10',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN' => 'BarnetTypes::TABLE_OF_BAPIRET2',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_PROBLEM_ID' => 'BarnetTypes::char35',
               'Z_CRM_SERVICE_ORDER_CREATE' => 'BarnetElements::Z_CRM_SERVICE_ORDER_CREATE',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_PROBLEM_LOC/REGION' => 'BarnetTypes::char3',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/LOG_MSG_NO' => 'BarnetTypes::numeric6',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/MESSAGE_V4' => 'BarnetTypes::char50',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/FIELD' => 'BarnetTypes::char30',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/SYSTEM' => 'BarnetTypes::char10',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_PROBLEM_LOC/COUNTY' => 'BarnetTypes::char30',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item/LOG_MSG_NO' => 'BarnetTypes::numeric6',
               'Z_CRM_SERVICE_ORDER_CREATE.Exception/Message' => 'BarnetTypes::RfcException::Message',
               'Z_CRM_SERVICE_ORDER_CREATE/IT_PROBLEM_DESC' => 'BarnetTypes::TABLE_OF_CRMT_SERVICE_REQUEST_TEXT',
               'Z_CRM_SERVICE_ORDER_CREATE/ET_RETURN/item' => 'BarnetTypes::BAPIRET2',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_PROBLEM_LOC/CITY' => 'BarnetTypes::char30',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/MESSAGE_V4' => 'BarnetTypes::char50',
               'Z_CRM_SERVICE_ORDER_CREATE.Exception' => 'BarnetElements::Z_CRM_SERVICE_ORDER_CREATE::Exception',
               'Fault' => 'SOAP::WSDL::SOAP::Typelib::Fault11',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_PROBLEM_LOC/STREETNUMBER' => 'BarnetTypes::char5',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/ID' => 'BarnetTypes::char20',
               'Fault/faultactor' => 'SOAP::WSDL::XSD::Typelib::Builtin::token',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_PROBLEM_LOC/STREET' => 'BarnetTypes::char30',
               'Z_CRM_SERVICE_ORDER_CREATE.Exception/Message/Number' => 'BarnetTypes::RfcException::Message::Number',
               'Z_CRM_SERVICE_ORDER_CREATE/IV_KBID' => 'BarnetTypes::char50',
               'Z_CRM_SERVICE_ORDER_CREATEResponse/ET_RETURN/item/MESSAGE_V3' => 'BarnetTypes::char50'
             };
;

sub get_class {
  my $name = join '/', @{ $_[1] };
  return $typemap_1->{ $name };
}

sub get_typemap {
    return $typemap_1;
}

1;

__END__

__END__

=pod

=head1 NAME

BarnetTypemaps::service - typemap for service

=head1 DESCRIPTION

Typemap created by SOAP::WSDL for map-based SOAP message parsers.

=cut

