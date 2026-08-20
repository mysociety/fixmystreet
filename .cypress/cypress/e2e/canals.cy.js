describe('Canals tests on non-CRT sites', function() {
    beforeEach(function() {
        // Make sure desktop
        cy.viewport(1500, 800);
        cy.intercept('**/mapserver/crt*', {fixture: 'canals.xml'}).as('crt-tilma');
        cy.intercept('**/report/new/ajax*').as('report-ajax');
    });
    describe('fixmystreet.com', function() {
        beforeEach(function() {
            cy.visit('http://fixmystreet.localhost:3001/report/new?longitude=-2.257592&latitude=51.856417'); // In Gloucester
            cy.wait('@crt-tilma');
            cy.wait('@report-ajax');
        });
        it('Select "on canal" option', function() {
            // Selected by default
            cy.nextPageReporting();
            cy.get('#form_category_fieldset').should('be.visible');
            cy.get('.hidden-canals-choice').contains('A pothole in pavement');
            cy.get('.hidden-canals-choice').contains('Bridges (CRT)').should('not.exist');
            cy.pickCategory('Bridges (CRT)');
            cy.nextPageReporting();
            cy.nextPageReporting();
            cy.get('#js-councils_text').contains('These will be sent to Canal & River Trust');
        });
        it('Select "somewhere else" option', function() {
            cy.get('#js-not-canals').click();
            cy.nextPageReporting();
            cy.get('#form_category_fieldset').should('be.visible');
            cy.get('.hidden-canals-choice').contains('A pothole in pavement').should('not.exist');
            cy.get('.hidden-canals-choice').contains('Bridges (CRT)');
            cy.pickCategory('A pothole in pavement');
            cy.nextPageReporting();
            cy.nextPageReporting();
            cy.get('#js-councils_text').contains('These will be sent to Gloucestershire County Council');
        });
    });
    describe('Gloucestershire site', function() {
        beforeEach(function() {
            cy.visit('http://gloucestershire.localhost:3001/report/new?longitude=-2.257592&latitude=51.856417');
            cy.wait('@crt-tilma');
            cy.wait('@report-ajax');
        });
        it('Select "on canal" option', function() {
            // Selected by default
            cy.nextPageReporting();
            cy.get('#form_category_fieldset').should('be.visible');
            cy.get('.hidden-canals-choice').contains('A pothole in pavement');
            cy.get('.hidden-canals-choice').contains('Bridges (CRT)').should('not.exist');
            cy.pickCategory('Bridges (CRT)');
            cy.nextPageReporting();
            cy.nextPageReporting();
            cy.get('#js-councils_text').contains('These will be sent to Canal & River Trust');
        });
        it('Select "somewhere else" option', function() {
            cy.get('#js-not-canals').click();
            cy.nextPageReporting();
            cy.get('#form_category_fieldset').should('be.visible');
            cy.get('.hidden-canals-choice').contains('A pothole in pavement').should('not.exist');
            cy.get('.hidden-canals-choice').contains('Bridges (CRT)');
            cy.pickCategory('A pothole in pavement');
            cy.nextPageReporting();
            cy.nextPageReporting();
            cy.get('#js-councils_text').contains('These will be sent to Gloucestershire County Council');
        });
    });
});
