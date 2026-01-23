/* Query the DVLA API on the tax status of a registration number */
// jshint esversion: 6

(function(){

const FIELDS = {
    'buckinghamshire': {
        'group': 'Abandoned/Nuisance vehicle',
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
    const fields = FIELDS[fixmystreet.cobrand];
    const yesno = document.querySelector('input[name=dvla_reg_have]:checked');

    if (!yesno) return;
    if (!yesno.value) {
        const field = document.querySelector('input[name*="' + fields.reg + '"]');
        if (field) {
            field.value = 'Not known';
        }
        return;
    }

    const reg_field = document.getElementById('dvla_reg');
    const reg = reg_field.value;
    if (!reg) return;

    e.preventDefault();
    e.stopPropagation();

    const page = document.querySelector('.js-dvla-page');
    page.classList.add('loading');

    $.post('/report/dvla', {'registration':reg}, function(data) {
        page.classList.remove('loading');
        if (data.errors) {
            const error = data.errors[0];
            if ($('#dvla_reg-error').length) {
                $('#dvla_reg-error').text(error.detail).show();
            } else {
                const $err = $('<div id="dvla_reg-error" class="form-error"><span class="visuallyhidden">Error:</span> ' + error.detail + '</div>');
                $(reg_field).before($err);
            }
            $(reg_field).addClass('form-error');
            return;
        }

        const reasons = [];
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

        const type = data.typeApproval || '';
        const wheelplan = data.wheelplan || '';
        let vehicle_type = '';
        if (type.match(/L[1-7]|motorcycle/i) || wheelplan.match(/motorcycle|moped|2 wheel/i)) {
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
            const stopperId = 'js-dvla-stopper';
            const $id = $('#' + stopperId);

            let vehicle_desc = [data.colour, data.make, vehicle_type=='Other'?'':vehicle_type.toLowerCase()].filter(Boolean).join(' ');
            if (data.fuelType) vehicle_desc += ', ' + data.fuelType;
            if (data.yearOfManufacture) vehicle_desc += ', ' + data.yearOfManufacture;
            const reason = 'We cannot accept reports on vehicles that ' + reasons.join(' or ');
            const $msg = $('<div class="js-stopper-notice box-warning"><strong>' + vehicle_desc + '</strong><br>' + reason + '. You may be able to <a href="https://contact.dvla.gov.uk/report-untaxed-vehicle">contact the DVLA</a>.</div>');
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
            let field = document.querySelector('input[name*="' + fields.colour + '"]');
            if (field) {
                const a = [];
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
    const fields = FIELDS[fixmystreet.cobrand];
    const selected = fixmystreet.reporting.selectedCategory();
    if (selected.group == fields.group) {
        const $msg = $(`<div class="js-dvla-message">

<div class="govuk-form-group">
  <fieldset class="govuk-radios govuk-radios--small">
   <legend>
      Do you know the vehicle’s registration number?
    </legend>
      <div class="govuk-radios__item">
        <input class="govuk-radios__input" id="dvla_reg_have_yes" name="dvla_reg_have" type="radio" value="1" data-show="#dvla_reg_field" required>
        <label class="govuk-label govuk-radios__label" for="dvla_reg_have_yes">Yes</label>
      </div>
      <div id="dvla_reg_field" class="hidden-js govuk-radios__conditional govuk-radios__conditional--hidden">
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

        let $div = $(".js-reporting-page.js-dvla-page");
        if (!$div.length) {
            $div = $("<div class='js-dvla-page'></div>");
        }
        $div.html($msg);
        $div.find('button').on('click', fixmystreet.dvla.lookup);
        $div.find('input[type=text]').on('keydown', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                $div.find('button').click();
            }
        });
        fixmystreet.pageController.addPageAfter('duplicates', 'dvla', $div);
        fixmystreet.set_up.toggle_visibility();
    } else {
        $(".js-dvla-page").remove();
    }
};

$(fixmystreet).on('report_new:category_change', fixmystreet.dvla.setup);

})();
