$(fixmystreet).on('report_new:category_change', function() {
    var witnessed = $('#form_fly_tip_witnessed');
    if (!witnessed) {
        return;
    }

    var when = $('#form_fly_tip_date_and_time');
    var whenLabel = $('label[for=form_fly_tip_date_and_time]');
    var offenderDescription = $('#form_description_of_alleged_offender');
    var offenderDescriptionLabel = $('label[for=form_description_of_alleged_offender]');

    function showAndRequire() {
        if (when) {
            when.show();
            when.prop('required', true);
        }
        if (offenderDescription) {
            offenderDescription.show();
            offenderDescription.prop('required', true);
        }
        if (whenLabel) {
            whenLabel.show();
        }
        if (offenderDescriptionLabel) {
            offenderDescriptionLabel.show();
        }
    }

    function hideAndUnrequire() {
        if (when) {
            when.hide();
            when.prop('required', false);
        }
        if (offenderDescription) {
            offenderDescription.hide();
            offenderDescription.prop('required', false);
        }
        if (whenLabel) {
            whenLabel.hide();
        }
        if (offenderDescriptionLabel) {
            offenderDescriptionLabel.hide();
        }
    }

    function checkAndToggle() { if (witnessed.val() === 'Yes') {
            showAndRequire();
        } else {
            hideAndUnrequire();
        }
    }

    checkAndToggle();
    witnessed.on('change', function() { checkAndToggle(); });
});
