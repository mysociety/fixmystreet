describe('Canal & River Trust cobrand tests', function() {
    beforeEach(function() {
        // Make sure desktop
        cy.viewport(1500, 800);
        cy.intercept('POST', '**/mapserver/crt', {fixture: 'canals.xml'}).as('crt-tilma');
        cy.intercept('**/report/new/ajax*').as('report-ajax');
    });
    it('does not allow reporting on non-canal', function() {
        cy.visit('http://canalrivertrust.localhost:3001/report/new?longitude=-2.257900&latitude=51.856700'); // In Gloucester
        cy.wait('@crt-tilma');
        cy.wait('@report-ajax');
        cy.get('.pre-button-messaging').contains('The selected location is not maintained by us.').should('be.visible');
        cy.get('.js-reporting-page--next').should('be.disabled');
    });
    it('allows reporting on canal', function() {
        cy.visit('http://canalrivertrust.localhost:3001/report/new?longitude=-2.257592&latitude=51.856417'); // In Gloucester
        cy.wait('@crt-tilma');
        cy.wait('@report-ajax');
        cy.get('.pre-button-messaging').contains('The selected location is not maintained by us.').should('not.exist');
        cy.pickCategory('Bridges');
        cy.nextPageReporting();
    });
});
