describe('Brent cobrand', function() {

    it('contains Brent configuration', function() {
        cy.viewport(480, 800);
        cy.visit('http://brent.localhost:3001/');
        cy.contains('Brent');
        cy.contains('Report it');
    });

});

describe('Queen’s Park', function() {
    it('does not permit reporting within the park', function() {
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
        cy.route('**/mapserver/brent*queens_park*', 'fixture:brent-queens_park.xml').as('queens_park');
        cy.visit('/report/new?longitude=-0.211045&latitude=51.534948');
        cy.wait('@report-ajax');
        cy.pickCategory('Dog fouling');
        cy.wait('@queens_park');
        cy.contains('maintained by the City of London').should('be.visible');
    });
});

describe('Brent road behaviour', function() {

    beforeEach(function() {
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
        cy.route('**/mapserver/brent*Highways*', 'fixture:brent-highways.xml').as('highways');
        cy.route('**/mapserver/tfl*RedRoutes*', 'fixture:brent-tfl.xml').as('tfl');
        cy.viewport(480, 800);
    });

    function make_flytip() {
        cy.get('#mob_ok').click();
        cy.wait('@report-ajax');
        cy.pickCategory('Fly-tipping');
        cy.wait('@highways');
        cy.wait('@tfl');
        cy.nextPageReporting();
    }

    it('prevents reporting not on a road', function() {
        cy.visit('http://brent.localhost:3001/report/new?longitude=-0.28168&latitude=51.55904');
        make_flytip();
        cy.contains('problem on the public highway').should('be.visible');
        cy.get('span').contains('Photo').should('not.be.visible');
    });

    it('allows reporting on a Brent road', function() {
        cy.visit('http://brent.localhost:3001/report/new?longitude=-0.276120&latitude=51.563683');
        make_flytip();
        cy.contains('problem on the public highway').should('not.be.visible');
        cy.get('span').contains('Photo').should('be.visible');
    });

    it('allows reporting on a TfL road', function() {
        cy.visit('http://brent.localhost:3001/report/new?longitude=-0.260869&latitude=51.551717');
        make_flytip();
        cy.contains('problem on the public highway').should('not.be.visible');
        cy.get('span').contains('Photo').should('be.visible');
    });
});
