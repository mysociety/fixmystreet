describe('Brent cobrand', function() {

    it('contains Brent configuration', function() {
        cy.viewport(480, 800);
        cy.visit('http://brent.localhost:3001/');
        cy.contains('Brent');
        cy.contains('Report it');
    });

});

describe('Brent asset layers', function() {

    beforeEach(function() {
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
        cy.route('**/mapserver/brent*Housing*', 'fixture:brent-housing.xml').as('housing');
        cy.route('**/mapserver/brent*Highways*', 'fixture:brent-highways.xml').as('highways');
        cy.route('**/mapserver/brent*Parks_and_Open_Spaces*', 'fixture:brent-park.xml').as('parks');
        cy.viewport(480, 800);
    });

    it('adds housing estate stopper when housing estate selected and removes it when not', function() {
        cy.visit('http://brent.localhost:3001/report/new?longitude=-0.277156&latitude=51.564493');
        cy.wait('@housing');
        cy.get('#mob_ok').should('not.be.visible');
        cy.contains('Please use our estate services page').should('be.visible');
        cy.visit('http://brent.localhost:3001/report/new?longitude=-0.28168&latitude=51.55904');
        cy.contains('Please use our estate services page').should('not.be.visible');
        cy.get('#mob_ok').should('be.visible');
    });

    it('adds park/highway stopper when not on park or highway for "Grass verges / shrub beds - littering"', function() {
        cy.visit('http://brent.localhost:3001/report/new?longitude=-0.28168&latitude=51.55904');
        cy.get('#mob_ok').click();
        cy.wait('@report-ajax');
        cy.pickCategory('Grass verges / shrub beds - littering');
        cy.wait('@highways');
        cy.wait('@parks');
        cy.nextPageReporting();
        cy.contains('Please select a park or highway from the map').should('be.visible');
        cy.get('span').contains('Photo').should('not.be.visible');
    });

    it('does not add park/highway stopper on park for "Grass verges / shrub beds - littering"', function() {
        cy.visit('http://brent.localhost:3001/report/new?longitude=-0.274082&latitude=51.563623');
        cy.get('#mob_ok').click();
        cy.wait('@report-ajax');
        cy.pickCategory('Grass verges / shrub beds - littering');
        cy.wait('@highways');
        cy.wait('@parks');
        cy.nextPageReporting();
        cy.contains('Please select a park or highway from the map').should('not.be.visible');
        cy.get('span').contains('Photo').should('be.visible');
    });

    it('does not add park/highway stopper on highway for "Grass verges / shrub beds - littering"', function() {
        cy.visit('http://brent.localhost:3001/report/new?longitude=-0.276120&latitude=51.563683');
        cy.get('#mob_ok').click();
        cy.wait('@report-ajax');
        cy.pickCategory('Grass verges / shrub beds - littering');
        cy.wait('@highways');
        cy.wait('@parks');
        cy.nextPageReporting();
        cy.contains('Please select a park or highway from the map').should('not.be.visible');
        cy.get('span').contains('Photo').should('be.visible');
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
        cy.contains('please select a point on a public road').should('be.visible');
        cy.get('span').contains('Photo').should('not.be.visible');
    });

    it('allows reporting on a Brent road', function() {
        cy.visit('http://brent.localhost:3001/report/new?longitude=-0.276120&latitude=51.563683');
        make_flytip();
        cy.contains('please select a point on a public road').should('not.be.visible');
        cy.get('span').contains('Photo').should('be.visible');
    });

    it('allows reporting on a TfL road', function() {
        cy.visit('http://brent.localhost:3001/report/new?longitude=-0.260869&latitude=51.551717');
        make_flytip();
        cy.contains('please select a point on a public road').should('not.be.visible');
        cy.get('span').contains('Photo').should('be.visible');
    });
});
