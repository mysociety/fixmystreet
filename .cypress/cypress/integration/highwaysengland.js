describe('National Highways cobrand tests', function() {
    beforeEach(function() {
        cy.server();
        cy.route('POST', '**/mapserver/highways', 'fixture:highways.xml').as('highways-tilma');
        cy.route('**/report/new/ajax*').as('report-ajax');
        cy.visit('http://highwaysengland.localhost:3001/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.url().should('include', '/around');
    });
    it('does not allow reporting on non-road', function() {
        cy.get('#map_box').click(280, 249);
        cy.wait('@highways-tilma');
        cy.wait('@report-ajax');
        cy.contains('Report a maintenance issue').should('be.visible');
        cy.contains('The selected location is not maintained by us.').should('be.visible');
    });
    it('does not allow reporting on DBFO roads', function() {
        cy.get('#map_box').click(200, 249);
        cy.wait('@highways-tilma');
        cy.wait('@report-ajax');
        cy.contains('Report a maintenance issue').should('be.visible');
        cy.contains('report on roads directly maintained').should('be.visible');
    });
    it('allows reporting on other HE roads', function() {
        cy.get('#map_box').click(240, 249);
        cy.wait('@highways-tilma');
        cy.wait('@report-ajax');
        cy.pickCategory('Fallen sign');
        cy.nextPageReporting();
        cy.contains('Report a maintenance issue').should('be.visible');
    });
});

describe('National Highways cobrand mobile tests', function() {
    it('does not allow reporting on DBFO roads on mobile either', function() {
        cy.server();
        cy.route('POST', '**/mapserver/highways', 'fixture:highways.xml').as('highways-tilma');
        cy.route('**/report/new/ajax*').as('report-ajax');

        cy.viewport(320, 568);
        cy.visit('http://highwaysengland.localhost:3001/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.url().should('include', '/around');

        cy.get('.olMapViewport')
            .trigger('mousedown', { which: 1, clientX: 160, clientY: 284 })
            .trigger('mousemove', { which: 1, clientX: 240, clientY: 284 })
            .trigger('mouseup', { which: 1, clientX: 240, clientY: 284 });

        cy.get('.map-mobile-report-button').click();
        cy.wait('@highways-tilma');
        cy.wait('@report-ajax');
        cy.contains('report on roads directly maintained').should('be.visible');
    });
});

describe('National Highways litter picking test', function() {
    beforeEach(function() {
        cy.server();
        cy.route('POST', '**/mapserver/highways', 'fixture:highways_a_road.xml').as('highways-tilma');
        cy.route('POST', '**/mapserver/highways?litter', 'fixture:highways_litter.xml').as('highways-tilma-litter');
        cy.route('**/report/new/ajax*').as('report-ajax');
        cy.visit('http://highwaysengland.localhost:3001/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.url().should('include', '/around');
    });
    it('stops litter reporting on roads where HE not responsible', function() {
        cy.get('#map_box').click(240, 249);
        cy.wait('@report-ajax');
        cy.wait('@highways-tilma');
        cy.wait('@highways-tilma-litter');
        cy.pickCategory('Flytipping');
        cy.contains('Report a litter issue').should('be.visible');
        cy.contains('litter issues on this road are handled by the local council').should('be.visible');
    });
});

describe('National Highways litter picking test', function() {
    beforeEach(function() {
        cy.server();
        cy.route('**/mapserver/highways*', 'fixture:highways_a_road.xml').as('highways-tilma');
        cy.route('**/report/new/ajax*', 'fixture:highways-ajax-he-referral.json').as('report-ajax');
    });
    it('filters to litter options on FMS', function() {
        cy.visit('http://fixmystreet.localhost:3001/report/new?longitude=-2.6030503&latitude=51.4966133&he_referral=1');
        cy.wait('@report-ajax');
        cy.wait('@highways-tilma');
        cy.contains('most appropriate option for the litter or flytipping');
        cy.contains('Street cleaning');
    });
});
