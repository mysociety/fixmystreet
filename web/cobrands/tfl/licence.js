// Licence forms: disable contractor fields when "same as applicant" is checked
(function() {
    var checkbox = document.getElementById('contractor_same_as_applicant-0');
    if (!checkbox) {
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
        var disabled = checkbox.checked;
        contractorFields.forEach(function(fieldName) {
            var field = document.getElementById(fieldName);
            if (field) {
                field.disabled = disabled;
            }
        });
    }

    checkbox.addEventListener('change', updateContractorFields);
    updateContractorFields();
})();
