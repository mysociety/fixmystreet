describe("Oxfordshire cobrand", function() {
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
                cy.get('@didetail').select(rdetail);
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

    var sweepfill = {
        typename: 'Sweep & Fill',
        right_details: [ 'Pothole Sweep & Fill 0-1m²', 'Pothole Cluster Sweep & Fill 1-2m²' ],
        wrong_details: [
             '0-1m²',
             '1-2m²',
             'Pothole Cluster',
             '1 kerb unit or I liner length',
             'Greater than 1 kerb unit or I liner length',
             'Blockage raised as a defect'
        ]
    };
    var pothole = {
        typename: 'Pothole (Permanent)',
        right_details: [ '0-1m²', '1-2m²' ],
        wrong_details: [
            'Pothole Sweep & Fill 0-1m²',
            'Pothole Cluster Sweep & Fill 1-2m²',
            'Pothole Cluster',
            '1 kerb unit or I liner length',
            'Greater than 1 kerb unit or I liner length',
            'Blockage raised as a defect'
        ]
    };
    var pothole_cluster = {
        typename: 'Pothole Cluster (Permanent)',
        right_details: [ 'Pothole Cluster' ],
        wrong_details: [
            '0-1m²',
            '1-2m²',
            'Pothole Sweep & Fill 0-1m²',
            'Pothole Cluster Sweep & Fill 1-2m²',
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
            '0-1m²',
            '1-2m²',
            'Pothole Sweep & Fill 0-1m²',
            'Pothole Cluster Sweep & Fill 1-2m²',
            'Pothole Cluster',
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
            '0-1m²',
            '1-2m²',
            'Pothole Sweep & Fill 0-1m²',
            'Pothole Cluster Sweep & Fill 1-2m²',
            'Pothole Cluster',
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
            '0-1m²',
            '1-2m²',
            'Pothole Sweep & Fill 0-1m²',
            'Pothole Cluster Sweep & Fill 1-2m²',
            'Pothole Cluster',
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
            '0-1m²',
            '1-2m²',
            'Pothole Sweep & Fill 0-1m²',
            'Pothole Cluster Sweep & Fill 1-2m²',
            'Pothole Cluster',
            'Blockage raised as a defect'
        ]
    };
    var blockage = {
        typename: 'Blockage',
        right_details: [
            'Blockage raised as a defect'
        ],
        wrong_details: [
            '0-1m²',
            '1-2m²',
            'Pothole Sweep & Fill 0-1m²',
            'Pothole Cluster Sweep & Fill 1-2m²',
            'Pothole Cluster',
            '1 kerb unit or I liner length',
            'Greater than 1 kerb unit or I liner length'
        ]
    };

    (function() {
        var right_types = [ sweepfill, pothole, pothole_cluster ];
        var wrong_types = [ damaged, loose, misaligned, missing, blockage ];

        testDefectDropdowns('Minor Carriageway', right_types, wrong_types);
        testDefectDropdowns('Footway/ Cycleway', right_types, wrong_types);
        cy.log('Minor Carriageway and Footway/ Cycleway category types & details are correct');
    }());

    (function() {
        var right_types = [ damaged, loose, misaligned, missing ];
        var wrong_types = [ sweepfill, pothole, pothole_cluster, blockage ];

        testDefectDropdowns('Kerbing', right_types, wrong_types);
        cy.log('Kerbing category types & details are correct');
    }());

    (function() {
        var right_types = [ blockage ];
        var wrong_types = [ sweepfill, pothole, pothole_cluster, damaged, loose, misaligned, missing ];

        testDefectDropdowns('Drainage', right_types, wrong_types);
        cy.log('Drainage category types & details are correct');
    }());

    // test reset all dropdowns
    cy.get('@dicat').select('-- Pick a category --');
    cy.get('@ditype').should('have.value', '');
    cy.get('@didetail').should('have.value', '');
  });
});
