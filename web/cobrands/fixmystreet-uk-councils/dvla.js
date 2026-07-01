/* Query the DVLA API on the tax status of a registration number */
// jshint esversion: 6

(function(){

const FIELDS = {
    'buckinghamshire': {
        'block': false,
        'group': 'Abandoned vehicle',
        'reg': 'VEHICLE_REGISTRATION',
        'taxed': 'ABANDONED_VEHICLE_TAXED',
        'type': 'ABANDONED_SELECT_TYPE',
        'make_and_colour': 'MAKE_/_COLOUR_OF_THE_VEHI',
        'tax': {
            'yes': 'Yes',
            'no': 'No'
        }
    },
    'bristol': {
        'block': true,
        'categories': [
            'A vehicle left on public road for over two months',
            'A vehicle abandoned on your property',
            'A badly damaged or burnt out vehicle on a public road',
        ],
        'reg': 'NE02',
        'taxed': 'NE01',
        'type': 'NE03',
        'make': 'NE04',
        'colour': 'NE06',
        'tax': {
            'yes': 'Y',
            'no': 'N'
        }
    },
    'greenwich': {
        'block': true,
        'categories': [
            'Abandoned vehicles'
        ],
        'reg': 'vehicle_registration',
        'make': 'vehicle_make',
        'colour': 'vehicle_colour',
    }
};

const TYPES = {
    'buckinghamshire': {
        'Motorbike': 'Motorbike',
        'Van': 'Van',
        'Car': 'Car',
        'Other': 'Other',
    },
    'bristol': {
        'Motorbike': 'MM',
        'Van': 'V',
        'Car': 'C',
        'Other': 'O',
    }
};

const REASONS = {
    'buckinghamshire': {
        'fn': function(data) {
            const reasons = [];
            if (data.taxStatus == 'Taxed') {
                reasons.push('are taxed');
            } else if (data.taxStatus == 'SORN') {
                reasons.push('have SORN status');
            }
            if (data.motStatus == 'Valid') {
                reasons.push('have a valid MOT');
            }
            return reasons.join(' or ');
        },
    },
    'greenwich': {
        fn: function (data) {
            if ( data.taxStatus == 'SORN' || (data.taxStatus == 'Taxed' && data.motStatus != 'Not valid')) {
               return 'This vehicle has a valid tax or MOT, so it does not meet the criteria for an abandoned vehicle report.';
            } else {
                return '';
            }
        }
    }
};

function title_case(str) {
    return str.replace(/\w\S*/g, text => text.charAt(0).toUpperCase() + text.substring(1).toLowerCase());
}

function esc(strings, ...params) {
    return strings.raw.reduce((acc, lit, i) => {
        let p = params[i-1];
        p = p.replace(/[^\w. ]/gi, c => '&#' + c.charCodeAt(0) + ';');
        return acc + p + lit;
    });
}

function dvla_lookup(e) {
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

    const request = new XMLHttpRequest();
    request.open('POST', '/report/dvla', true);
    request.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
    request.onload = function response() {
        const data = JSON.parse(this.response);
        page.classList.remove('loading');
        if (data.errors) {
            const error = data.errors[0];
            const error_elt = document.getElementById('dvla_reg-error');
            if (error_elt) {
                error_elt.textContent = error.detail;
                error_elt.style.display = '';
            } else {
                const err = esc`<div id="dvla_reg-error" class="form-error"><span class="visuallyhidden">Error:</span> ${error.detail}</div>`;
                reg_field.insertAdjacentHTML('beforebegin', err);
            }
            reg_field.classList.add('form-error');
            return;
        }

        const council_reasons = REASONS[fixmystreet.cobrand] || {};
        let reason = '';
        let add_dvla_contact = true;
        if (council_reasons.fn) {
            reason = council_reasons.fn(data);
        } else {
            if (data.taxStatus == 'SORN') {
                reason = 'We cannot accept reports on vehicles that have been declared SORN but are left on a public road, contact DVLA: <a href="https://www.gov.uk/sorn-statutory-off-road-notification">SORN guidance</a> · <a href="https://www.gov.uk/make-a-sorn">Make a SORN</a>';
                add_dvla_contact = false;
            } else {
                const reason_msgs = [];
                if (data.taxStatus == 'Taxed') {
                    reason_msgs.push('are taxed');
                }
                if (data.motStatus == 'Valid') {
                    reason_msgs.push('have a valid MOT');
                }
                if (reason_msgs.length) {
                    reason = 'We cannot accept reports on vehicles that ' + reason_msgs.join(' or ') + '.';
                }
            }
        }

        data.reg = reg;
        data.make = title_case(data.make || '');
        data.colour = title_case(data.colour || '');
        data.fuelType = title_case(data.fuelType || '');
        const make_and_colour = [];
        if (data.make) make_and_colour.push(data.make);
        if (data.colour) make_and_colour.push(data.colour);
        data.make_and_colour = make_and_colour.join(' / ');

        const type = data.typeApproval || '';
        const wheelplan = data.wheelplan || '';
        let types = TYPES[fixmystreet.cobrand] || '';
        let vehicle_type = '';
        if (types) {
            if (type.match(/L[1-7]|motorcycle/i) || wheelplan.match(/motorcycle|moped|2 wheel/i)) {
                vehicle_type = types.Motorbike;
            } else if (type.match(/N1|commercial/i) || wheelplan.match(/van|commercial/i)) {
                vehicle_type = types.Van;
            } else if (type.match(/M1/i)) {
                vehicle_type = types.Car;
            } else if (type.match(/M[23]|N[23]/i) || wheelplan.match(/& artic|3 axle rigid|multi-axle rigid/i)) {
                vehicle_type = types.Other;
            }
        }

        const config = FIELDS[fixmystreet.cobrand] || {};
        if (config.block && reason != '') {
            document.querySelectorAll('.js-reporting-page--next').forEach(b => b.disabled = true);
            const stopperId = 'js-dvla-stopper';
            const id = document.getElementById(stopperId);

            let vehicle_desc = [data.colour, data.make, vehicle_type=='Other'?'':vehicle_type.toLowerCase()].filter(Boolean).join(' ');
            if (data.fuelType) vehicle_desc += ', ' + data.fuelType;
            if (data.yearOfManufacture) vehicle_desc += ', ' + data.yearOfManufacture;
            const msg = esc`<div id="${stopperId}" class="js-stopper-notice box-warning" role="alert" aria-live="assertive"><strong>${vehicle_desc}</strong><br>` + reason + ( add_dvla_contact ? 'You may be able to <a href="https://contact.dvla.gov.uk/report-untaxed-vehicle">contact the DVLA</a>.' : '' ) + '</div>';
            const wrapper = document.querySelector('.js-reporting-page--active .pre-button-messaging');
            if (id) {
                id.outerHTML = msg;
            } else {
                wrapper.insertAdjacentHTML('afterbegin', msg);
            }
            const height = wrapper.getBoundingClientRect().height;
            document.querySelector('.js-reporting-page--active').style.paddingBottom = height;
        } else {
            ['make', 'colour', 'reg', 'make_and_colour'].forEach(name => {
                if (fields[name] && data[name]) {
                    let field = document.querySelector('input[name*="' + fields[name] + '"]');
                    if (field) {
                        field.value = data[name];
                    }
                }
            });

            let field = document.querySelector('select[name*="' + fields.type + '"]');
            if (field && vehicle_type) {
                field.value = vehicle_type;
            }
            field = document.querySelector('select[name*="' + fields.taxed + '"]');
            if (field) {
                if (data.taxStatus == 'Taxed') {
                    field.value = config.tax.yes;
                } else if (data.taxStatus == 'Untaxed') {
                    field.value = config.tax.no;
                }
            }
            fixmystreet.pageController.toPage('next');
        }
    };
    request.send(`registration=${encodeURIComponent(reg)}`);
}

function dvla_setup() {
    const fields = FIELDS[fixmystreet.cobrand];
    const selected = fixmystreet.reporting.selectedCategory();
    if (selected.group == fields.group || (fields.categories && fields.categories.indexOf(selected.category) > -1) ) {
        const msg = `<div class="js-dvla-message">

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
`;

        let div = document.querySelector(".js-reporting-page.js-dvla-page");
        if (!div) {
            div = document.createElement('div');
            div.className = 'js-dvla-page';
        }
        div.innerHTML = msg;
        div.querySelector('button').addEventListener('click', dvla_lookup);
        div.querySelector('input[type=text]').addEventListener('keydown', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                div.querySelector('button').click();
            }
        });
        fixmystreet.pageController.addPageAfter('duplicates', 'dvla', $(div));
        fixmystreet.set_up.toggle_visibility();
    } else {
        const page = document.querySelector('.js-dvla-page');
        if (page) {
            page.remove();
        }
    }
}

$(fixmystreet).on('report_new:category_change', dvla_setup);

})();
