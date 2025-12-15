/* Query the DVLA API on the tax status of a registration number */
// jshint esversion: 6

(function(){

var FIELDS = {
    'buckinghamshire': {
        'reg': 'VEHICLE_REGISTRATION',
        'taxed': 'ABANDONED_VEHICLE_TAXED',
        'type': 'ABANDONED_SELECT_TYPE',
        'colour': 'COLOUR_OF_THE'
    }
};

fixmystreet.dvla = {};

function title_case(str) {
    return str.replace(/\w\S*/g, text => text.charAt(0).toUpperCase() + text.substring(1).toLowerCase());
}

fixmystreet.dvla.lookup = function(e) {
    var yesno = document.querySelector('input[name=dvla_reg_have]:checked');

    var fields = FIELDS[fixmystreet.cobrand];

    if (!yesno) return;
    yesno = yesno.value;
    if (!yesno) {
        field = document.querySelector('input[name*="' + fields.reg + '"]');
        if (field) {
            field.value = 'Not known';
        }
        return;
    }
    var reg = document.getElementById('dvla_reg').value;
    if (!reg) return;
    e.preventDefault();
    e.stopPropagation();
    $.post('/report/dvla', {'registration':reg}, function(data) {
        var reasons = [];
        if (data.taxStatus == 'Taxed') {
            reasons.push('are taxed');
        } else if (data.taxStatus == 'SORN') {
            reasons.push('have SORN status');
        }
        if (data.motStatus == 'Valid') {
            reasons.push('have a valid MOT');
        }

        data.make = title_case(data.make || '');
        data.colour = title_case(data.colour || '');
        data.fuelType = title_case(data.fuelType || '');

        var type = data.typeApproval || '';
        var wheelplan = data.wheelplan || '';
        var vehicle_type = '';
        if (type.match(/L[1-7]|motorcycle/i) || wheelplan.match(/motorcyle|moped|2 wheel/i)) {
            vehicle_type = 'Motorbike';
        } else if (type.match(/N1|commercial/i) || wheelplan.match(/van|commercial/i)) {
            vehicle_type = 'Van';
        } else if (type.match(/M1/i)) {
            vehicle_type = 'Car';
        } else if (type.match(/M[23]|N[23]/i) || wheelplan.match(/& artic|3 axle rigid|multi-axle rigid/i)) {
            vehicle_type = 'Other';
        }

        if (reasons.length) {
            $('.js-reporting-page--next').prop('disabled', true);
            var stopperId = 'js-dvla-stopper';
            var $id = $('#' + stopperId);

            var vehicle_desc = [data.colour, data.make, vehicle_type=='Other'?'':vehicle_type.toLowerCase()].filter(Boolean).join(' ');
            if (data.fuelType) vehicle_desc += ', ' + data.fuelType;
            if (data.yearOfManufacture) vehicle_desc += ', ' + data.yearOfManufacture;
            var reason = 'We cannot accept reports on vehicles that ' + reasons.join(' or ');
            $msg = $('<div class="js-stopper-notice box-warning"><strong>' + vehicle_desc + '</strong><br>' + reason + '. You may be able to <a href="https://contact.dvla.gov.uk/report-untaxed-vehicle">contact the DVLA</a>.</div>');
            $msg.attr('id', stopperId);
            $msg.attr('role', 'alert');
            $msg.attr('aria-live', 'assertive');
            if ($id.length) {
                $id.replaceWith($msg);
            } else {
                $msg.prependTo('.js-reporting-page--active .pre-button-messaging');
            }
            $('.js-reporting-page--active').css('padding-bottom', $('.js-reporting-page--active .pre-button-messaging').height());
        } else {
            var field = document.querySelector('input[name*="' + fields.colour + '"]');
            if (field) {
                var a = [];
                if (data.make) a.push(data.make);
                if (data.colour) a.push(data.colour);
                field.value = a.join(' / ');
            }
            field = document.querySelector('select[name*="' + fields.type + '"]');
            if (field && vehicle_type) {
                field.value = vehicle_type;
            }
            field = document.querySelector('select[name*="' + fields.taxed + '"]');
            if (field && !data.errors) {
                field.value = 'No';
            }
            field = document.querySelector('input[name*="' + fields.reg + '"]');
            if (field) {
                field.value = reg;
            }
            fixmystreet.pageController.toPage('next');
        }
    });
};

fixmystreet.dvla.setup = function() {
    var selected = fixmystreet.reporting.selectedCategory();
    if (selected.group == 'Abandoned/Nuisance vehicle') {
        var $msg = $(`<div class="js-dvla-message">

<div class="govuk-form-group">
  <fieldset class="govuk-radios govuk-radios--small">
   <legend>
      Do you know the vehicle’s registration number?
    </legend>
      <div class="govuk-radios__item">
        <input class="govuk-radios__input" id="dvla_reg_have_yes" name="dvla_reg_have" type="radio" value="1" data-show="#dvla_reg_field" required>
        <label class="govuk-label govuk-radios__label" for="dvla_reg_have_yes">Yes</label>
      </div>
      <div id="dvla_reg_field" class="hidden-js govuk-radios__conditional govuk-radios__conditional--hidden" id="conditional-contact">
        <div class="govuk-form-group">
          <label class="govuk-label" for="dvla_reg">Registration number</label>
          <input class="govuk-input required" id="dvla_reg" name="dvla_reg" type="text" spellcheck="false">
        </div>
      </div>
      <div class="govuk-radios__item">
        <input class="govuk-radios__input" id="dvla_reg_have_no" name="dvla_reg_have" type="radio" value="" data-hide="#dvla_reg_field">
        <label class="govuk-label govuk-radios__label" for="dvla_reg_have_no">No</label>
      </div>
  </fieldset>
</div>

</div>

<div class="floating-button-spacer"><div class="floating-button-wrapper"><div class="floating-button">
        <div class="pre-button-messaging"></div>
        <button class="btn btn--block btn--primary js-reporting-page--next">Continue</button>
</div></div></div>
`);

        var $div = $(".js-reporting-page.js-dvla-page");
        if (!$div.length) {
            $div = $("<div class='js-dvla-page'></div>");
        }
        $div.html($msg);
        $div.find('button').on('click', fixmystreet.dvla.lookup);
        fixmystreet.pageController.addPageAfter('duplicates', 'dvla', $div);
        fixmystreet.set_up.toggle_visibility();
    } else {
        $(".js-dvla-page").remove();
    }
};

$(fixmystreet).on('report_new:category_change', fixmystreet.dvla.setup);

})();
