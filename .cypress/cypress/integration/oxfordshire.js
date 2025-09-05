describe("Oxfordshire cobrand", function() {
  it("looks up private street light information", function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('*oxfordshire.staging*', 'fixture:oxon-street-lights.json').as('street-lights-layer');
    cy.visit('http://oxfordshire.localhost:3001/report/new?latitude=51.754926&longitude=-1.256179');
    cy.wait('@report-ajax');
    cy.pickCategory('Lamp Out of Light');
    cy.wait('@street-lights-layer');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('circle').eq(1).click(); // Click a public light
    cy.get(".pre-button-messaging").should('not.contain', 'private street light asset');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
    cy.get('circle').eq(0).click(); // Click a private light
    cy.get(".pre-button-messaging").should('contain', 'private street light asset');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
  });

  it("allows inspectors to instruct defects", function() {
    cy.server();
    cy.route('/report/*').as('show-report');

    cy.visit('http://oxfordshire.localhost:3001/_test/setup/oxfordshire-defect');

    cy.request({
      method: 'POST',
      url: 'http://oxfordshire.localhost:3001/auth',
      form: true,
      body: { username: 'inspector-instructor@example.org', password_sign_in: 'password' }
    });

    cy.visit('http://oxfordshire.localhost:3001/report/1');
    cy.contains('Oxfordshire');
    cy.contains('Problems nearby').click();
    cy.get('[href$="/report/1"]').last().click();
    cy.wait('@show-report');

    cy.get('#report_inspect_form').should('be.visible');
    cy.get('#js-inspect-action-scheduled').should('not.be.visible');
    cy.get('#raise_defect_yes').should('not.have.attr', 'required');

    cy.get('#report_inspect_form select[name=state]').select('Action scheduled');
    cy.get('#js-inspect-action-scheduled').should('be.visible');
    cy.get('#raise_defect_yes').should('have.attr', 'required', 'required');
    cy.get('#raise_defect_yes').click({force: true});
    cy.get('#defect_item_category').should('be.visible');

    cy.get('#report_inspect_form select[name=state]').select('No further action');
    cy.get('#js-inspect-action-scheduled').should('not.be.visible');
    cy.get('#raise_defect_yes').should('not.have.attr', 'required');

    cy.visit('http://oxfordshire.localhost:3001/_test/teardown/oxfordshire-defect');
  });

  it("shows the correct dropdown options for each category", function() {
    cy.request({
      method: 'POST',
      url: 'http://oxfordshire.localhost:3001/auth',
      form: true,
      body: { username: 'inspector-instructor@example.org', password_sign_in: 'password' }
    });
    cy.visit('http://oxfordshire.localhost:3001/report/1');

    cy.get('#report_inspect_form').should('be.visible');
    cy.get('#js-inspect-action-scheduled').should('not.be.visible');
    cy.get('#raise_defect_yes').should('not.have.attr', 'required');

    cy.get('#report_inspect_form select[name=state]').select('Action scheduled');
    cy.get('#js-inspect-action-scheduled').should('be.visible');
    cy.get('#raise_defect_yes').should('have.attr', 'required', 'required');
    cy.get('#raise_defect_yes').click({force: true});
    cy.get('#defect_item_category').should('be.visible');
 
    // test defect dropdowns' interaction
    cy.get('#defect_item_category').as('dicat');
    cy.get('#defect_item_type').as('ditype');
    cy.get('#defect_item_detail').as('didetail');


    function testDefectDropdowns(catval, righttypes, wrongtypes) {
        // select cat
        cy.get('@dicat').select(catval);

        // check types
        righttypes.forEach(function(rtype) {
            cy.get('@ditype').select(rtype.typename);

            // check details
            rtype.right_details.forEach(function(rdetail) {
                cy.get('@didetail').find('optgroup', "'" + rtype.typename + "'").contains(new RegExp('^' + rdetail + '$')).should('be.visible');
            });
            rtype.wrong_details.forEach( function(wdetail) {
                cy.get('@didetail').contains(new RegExp('^' + wdetail + '$')).parent('optgroup').should('not.be.visible');
            });
        });
        wrongtypes.forEach(function(wtype) {
            var t = wtype.typename.replace('(','\\(').replace(')','\\)');
            cy.get('@ditype').contains(new RegExp('^' + t + '$')).parent('optgroup').should('not.be.visible');
        });
    }

    var pothole = {
        typename: 'Pothole (Permanent)',
        right_details: [ '0-0.5m²', '0.5-1m²', '1-2m²' ],
        wrong_details: [
            '1 kerb unit or I liner length',
            'Greater than 1 kerb unit or I liner length',
            'Blockage raised as a defect'
        ]
    };
    var damaged = {
        typename: 'Damaged',
        right_details: [
            '1 kerb unit or I liner length',
            'Greater than 1 kerb unit or I liner length',
        ],
        wrong_details: [
            '0-0.5m²', '0.5-1m²', '1-2m²',
            'Blockage raised as a defect'
        ]
    };
    var loose = {
        typename: 'Loose',
        right_details: [
            '1 kerb unit or I liner length',
            'Greater than 1 kerb unit or I liner length'
        ],
        wrong_details: [
            '0-0.5m²', '0.5-1m²', '1-2m²',
            'Blockage raised as a defect'
        ]
    };
    var misaligned = {
        typename: 'Misaligned Single Units or Uneven Run of Units',
        right_details: [
            '1 kerb unit or I liner length',
            'Greater than 1 kerb unit or I liner length'
        ],
        wrong_details: [
            '0-0.5m²', '0.5-1m²', '1-2m²',
            'Blockage raised as a defect'
        ]
    };
    var missing = {
        typename: 'Missing',
        right_details: [
            '1 kerb unit or I liner length',
            'Greater than 1 kerb unit or I liner length'
        ],
        wrong_details: [
            '0-0.5m²', '0.5-1m²', '1-2m²',
            'Blockage raised as a defect'
        ]
    };
    var blockage = {
        typename: 'Blockage',
        right_details: [
            'Blockage raised as a defect'
        ],
        wrong_details: [
            '0-0.5m²', '0.5-1m²', '1-2m²',
            '1 kerb unit or I liner length',
            'Greater than 1 kerb unit or I liner length'
        ]
    };

    (function() {
        var right_types = [ pothole ];
        var wrong_types = [ damaged, loose, misaligned, missing, blockage ];

        testDefectDropdowns('Minor Carriageway', right_types, wrong_types);
        testDefectDropdowns('Footway/ Cycleway', right_types, wrong_types);
        cy.log('Minor Carriageway and Footway/ Cycleway category types & details are correct');
    }());

    (function() {
        var right_types = [ damaged, loose, misaligned, missing ];
        var wrong_types = [ pothole, blockage ];

        testDefectDropdowns('Kerbing', right_types, wrong_types);
        cy.log('Kerbing category types & details are correct');
    }());

    (function() {
        var right_types = [ blockage ];
        var wrong_types = [ pothole, damaged, loose, misaligned, missing ];

        testDefectDropdowns('Drainage', right_types, wrong_types);
        cy.log('Drainage category types & details are correct');
    }());

    // test reset all dropdowns
    cy.get('@dicat').select('-- Pick a category --');
    cy.get('@ditype').should('have.value', '');
    cy.get('@didetail').should('have.value', '');
  });
});
