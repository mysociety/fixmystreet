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
            var field = document.getElementById('form-' + fieldName + '-row');
            if (field) {
                field.classList.toggle('hidden-js', disabled);
            }
        });
    }

    checkbox.addEventListener('change', updateContractorFields);
    updateContractorFields();
})();

// Licence forms: update end date when weeks changed
(function() {
    var row = document.getElementById('form-proposed_duration-row');
    if (!row) {
        return;
    }

    function updateEndDateFromChecked() {
        var checked = row.querySelector('input:checked');
        if (checked) {
            updateEndDate(checked.value);
        }
    }

    function updateEndDate(weeks) {
        var d = document.getElementById('proposed_start_date.day').value,
            m = document.getElementById('proposed_start_date.month').value,
            y = document.getElementById('proposed_start_date.year').value,
            date = new Date(y, m-1, d),
            end = document.getElementById('js-proposed_end_date');
        date.setDate(date.getDate() + weeks * 7);
        end.innerHTML = 'Your proposed end date will be ' + date.toLocaleDateString() + '.<br><br>';
    }

    row.addEventListener('change', updateEndDateFromChecked);
    document.getElementById('proposed_start_date').addEventListener('change', updateEndDateFromChecked);
    updateEndDateFromChecked();
})();
