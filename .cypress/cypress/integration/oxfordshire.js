describe("Oxfordshire highways messages", function() {
    beforeEach(function() {
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
    });
    function pick_flytipping() {
        cy.visit('http://oxfordshire.localhost:3001/report/new?longitude=-1.570014&latitude=51.862035');
        cy.wait('@report-ajax');
        cy.pickCategory('Flytipping');
    }
    it('displays nearby roadworks and oxfordshire highways messages', function() {
        cy.route('POST', '**proxy/occ/nsg/**', 'fixture:oxfordshire_roadworks.xml').as('highwaysworks');
        cy.route('/streetmanager.php**', 'fixture:oxfordshire_roadworks.json').as('roadworks');
        pick_flytipping();
        cy.wait('@roadworks');
        cy.wait('@highwaysworks');
        cy.nextPageReporting();
        cy.get('.js-roadworks-message').scrollIntoView();
        cy.contains('Immediate emergency works, with road closure').should('be.visible');
        cy.get('#map_sidebar').scrollTo('bottom');
        cy.contains('Shipton Road heading out towards shipton').should('be.visible');
        cy.nextPageReporting();
        cy.contains('Drag photos here').should('be.visible');
      });
      it('displays nearby roadworks when no highways messages', function() {
        cy.route('/streetmanager.php**', 'fixture:oxfordshire_roadworks.json').as('roadworks');
        pick_flytipping();
        cy.wait('@roadworks');
        cy.nextPageReporting();
        cy.get('.js-roadworks-message').scrollIntoView();
        cy.contains('Immediate emergency works, with road closure').should('be.visible');
        cy.nextPageReporting();
        cy.contains('Drag photos here').should('be.visible');
      });
      it('display oxfordshire highways messages when no roadworks', function() {
        cy.route('POST', '**proxy/occ/nsg/**', 'fixture:oxfordshire_roadworks.xml').as('highwaysworks');
        pick_flytipping();
        cy.wait('@highwaysworks');
        cy.nextPageReporting();
        cy.contains('Shipton Road heading out towards shipton').should('be.visible');
        cy.nextPageReporting();
        cy.contains('Drag photos here').should('be.visible');
      });
      it('skips roadworks page when no nearby roadworks or Oxfordshire Highways messages', function() {
        pick_flytipping();
        cy.nextPageReporting();
        cy.contains('Drag photos here').should('be.visible');
      });
});

describe("Oxfordshire highways messages filter", function() {
    beforeEach(function() {
        cy.server();
        cy.fixture('oxfordshire_roadworks.xml');
        cy.route('POST', '**proxy/occ/nsg/**', 'fixture:oxfordshire_roadworks.xml').as('highwaysworks');
    });

    it('Filters on 2022/23 year', function() {
        cy.clock(Date.UTC(2022, 3, 6), ['Date']);
        cy.visit('http://oxfordshire.localhost:3001/report/new?longitude=-1.570014&latitude=51.862035');
        cy.pickCategory('Flytipping');
        cy.wait('@highwaysworks').should(function(xhr) {
            expect(xhr.requestBody).to.include('2022/23');
        });
    });
    it('Filters on 2022/23 year', function() {
        cy.clock(Date.UTC(2023, 3, 5), ['Date']);
        cy.visit('http://oxfordshire.localhost:3001/report/new?longitude=-1.570014&latitude=51.862035');
        cy.pickCategory('Flytipping');
        cy.wait('@highwaysworks').should(function(xhr) {
            expect(xhr.requestBody).to.include('2022/23');
        });
    });
    it('Filters on 2023/24 year', function() {
        cy.clock(Date.UTC(2023, 3, 6), ['Date']);
        cy.visit('http://oxfordshire.localhost:3001/report/new?longitude=-1.570014&latitude=51.862035');
        cy.pickCategory('Flytipping');
        cy.wait('@highwaysworks').should(function(xhr) {
            expect(xhr.requestBody).to.include('2023/24');
        });
    });
    it('Filters on 2051/52 year', function() {
        cy.clock(Date.UTC(2052, 3, 5), ['Date']);
        cy.visit('http://oxfordshire.localhost:3001/report/new?longitude=-1.570014&latitude=51.862035');
        cy.pickCategory('Flytipping');
        cy.wait('@highwaysworks').should(function(xhr) {
            expect(xhr.requestBody).to.include('2051/52');
        });
    });
    it('Filters on 2052/53 year', function() {
        cy.clock(Date.UTC(2052, 3, 6), ['Date']);
        cy.visit('http://oxfordshire.localhost:3001/report/new?longitude=-1.570014&latitude=51.862035');
        cy.pickCategory('Flytipping');
        cy.wait('@highwaysworks').should(function(xhr) {
            expect(xhr.requestBody).to.include('2052/53');
        });
    });
});

describe("Oxfordshire cobrand", function() {
  it("looks up private street light information", function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('*oxfordshire.staging*', 'fixture:oxon-street-lights.json').as('street-lights-layer');
    cy.visit('http://oxfordshire.localhost:3001/report/new?latitude=51.754926&longitude=-1.256179');
    cy.wait('@report-ajax');
    cy.pickCategory('Lamp Out of Light');
    cy.wait('@street-lights-layer');
    cy.get('#map_sidebar').scrollTo('bottom');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('circle').eq(1).click(); // Click a public light
    cy.get("#category_meta_message_LampOutofLight").should('not.contain', 'private street light asset');
    cy.get('#map_sidebar').scrollTo('bottom');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
    cy.get('circle').eq(0).click(); // Click a private light
    cy.get("#category_meta_message_LampOutofLight").should('contain', 'private street light asset');
    cy.get('#map_sidebar').scrollTo('bottom');
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
        right_details: [ '0-1m²', '1-2m²' ],
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
            '0-1m²',
            '1-2m²',
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
