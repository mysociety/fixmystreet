// Licence forms: disable contractor fields when "same as applicant" is checked
$(function() {
    var $checkbox = $('#contractor_same_as_applicant-0');
    if (!$checkbox.length) {
        return;
    }

    var contractorFields = [
        'contractor_organisation',
        'contractor_contact_name',
        'contractor_address',
        'contractor_email',
        'contractor_phone',
        'contractor_phone_24h'
    ];

    function updateContractorFields() {
        var disabled = $checkbox.is(':checked');
        contractorFields.forEach(function(fieldName) {
            $('#' + fieldName).prop('disabled', disabled);
        });
    }

    $checkbox.on('change', updateContractorFields);
    updateContractorFields();
});
