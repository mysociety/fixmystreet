describe('Surrey cobrand', function() {
    it('contains Surrey configuration', function() {
        cy.viewport(480, 800);
        cy.visit('http://surrey.localhost:3001/');
        cy.contains('Surrey');
    });
});

describe('Reporting not on a road', function() {
    it('Can report certain categories not on a road', function() {
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
        cy.visit('http://surrey.localhost:3001/report/new?longitude=-0.441269&latitude=51.293415');
        cy.wait('@report-ajax');
        cy.pickCategory('Abandoned vehicles');
        cy.contains('You cannot send Surrey County Council a report');
        cy.get('#map_sidebar').scrollTo('bottom');
        cy.get('.js-reporting-page--next:visible').should('be.disabled');
        cy.pickCategory('Flooding inside a building');
        cy.contains('You cannot send Surrey County Council a report').should('not.be.visible');
        cy.get('#map_sidebar').scrollTo('bottom');
        cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
    });
});


