function setupWitnessRelatedFieldChanges() {
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
}

$(fixmystreet).on('report_new:category_change', function() {
    var categorySelection = fixmystreet.reporting.selectedCategory();
    var match = categorySelection.category === "Fly Tipping" &&
        fixmystreet.bodies.includes("Central Bedfordshire Council");

    var descriptionTips = $("#description-tips");
    var photoTipsDont = $("#photo-tips-dont");

    if (match) {
        setupWitnessRelatedFieldChanges();
        if (descriptionTips) {
            descriptionTips.hide();
        }
        if (photoTipsDont) {
            photoTipsDont.hide();
        }
    } else {
        if (descriptionTips) {
            descriptionTips.show();
        }
        if (photoTipsDont) {
            photoTipsDont.show();
        }
    }
});
