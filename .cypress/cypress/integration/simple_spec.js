describe('Clicking the map', function() {
    beforeEach(function(){
        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
    });

    it('allows me to report a new problem', function() {
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
        cy.url().should('include', '/around');
        cy.get('#map_box').click(200, 200);
        cy.wait('@report-ajax');
        cy.pickCategory('Flyposting');
        cy.nextPageReporting();
        cy.nextPageReporting(); // No photo
        cy.get('[name=title]').type('Title');
        cy.get('[name=detail]').type('Detail');
        cy.nextPageReporting();
        cy.get('.js-new-report-show-sign-in').should('be.visible').click();
        cy.get('#form_username_sign_in').type('user@example.org');
        cy.get('[name=password_sign_in]').type('password');
        cy.get('[name=password_sign_in]').parents('form').submit();
        cy.get('#map_sidebar').should('contain', 'check and confirm your details');
        cy.get('#form_service').should('have.value', 'desktop');
        cy.get('#map_sidebar').parents('form').submit();
        cy.get('body').should('contain', 'Thank you for reporting this issue');
        cy.visit('http://fixmystreet.localhost:3001/_test/setup/simple-service-check').then(function(w) {
            expect(w.document.documentElement.innerText).to.equal('desktop');
        });
    });

    it('map pins toggle okay', function() {
        cy.get('.map-layer-toggle').click();
        cy.get('.map-layer-toggle').should('have.class', 'roads');
        cy.get('.map-layer-toggle').click();
        cy.get('.map-layer-toggle').should('have.class', 'aerial');

        cy.get('.map-pins-toggle').click();
        cy.get('.map-pins-toggle').should('contain', 'Show pins');
        cy.get('.map-pins-toggle').click();
        cy.get('.map-pins-toggle').should('contain', 'Hide pins');
    });
});

describe('Leaving updates', function() {
    function leave_update() {
        cy.get('[name=update]').type('Update');
        cy.get('.js-new-report-user-show').last().click();
        cy.get('.js-new-report-show-sign-in').last().should('be.visible').click();
        // [id=].last() due to #2341
        cy.get('[id=form_username_sign_in]').last().type('user@example.org');
        cy.get('[name=password_sign_in]').last().type('password');
        cy.get('[name=password_sign_in]').last().parents('form').first().submit();
        cy.get('#map_sidebar').should('contain', 'check and confirm your details');
        cy.get('[name=submit_register]').parents('form').submit();
        cy.get('body').should('contain', 'Thank you for updating this issue');
    }

    it('works when visited directly', function() {
        cy.visit('/report/15');
        leave_update();
    });

    it('works when pulled in via JS', function() {
        cy.server();
        cy.route('/report/*').as('show-report');
        cy.route('/reports/*').as('show-all');
        cy.route('/mapit/area/*').as('get-geometry');
        cy.visit('/around?lon=-2.295894&lat=51.526877&zoom=0');
        // force to hopefully work around apparent Cypress SVG issue
        cy.get('image[title="Lights out in tunnel"]').last().click({force: true});
        cy.wait('@show-report');
        leave_update();
    });
});

describe('Clicking the "big green banner" on a map page', function() {
    before(function() {
        cy.server();
        cy.route('/around\?ajax*').as('update-results');
        cy.visit('/');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.wait('@update-results');
        cy.get('.big-green-banner').click();
    });

    it('begins a new report', function() {
        cy.url().should('include', '/report/new');
        // Clicked randomly in middle of map, so no body, so top message shown
        cy.get('#js-top-message').should('be.visible');
        cy.get('.js-reporting-page--next').should('be.visible');
    });
});

describe.only('Clicking on drawers', function() {
    it('works on a direct report page', function() {
        cy.visit('/report/15');
        cy.contains('Get updates').click();
        cy.contains('Receive email when updates are left').should('be.visible');
        cy.contains('Get updates').click();
        cy.contains('Receive email when updates are left').should('not.be.visible');
    });

    it('works on a pulled-in report page', function() {
        cy.server();
        cy.route('/report/*').as('show-report');
        cy.visit('/around?lon=-2.295894&lat=51.526877&zoom=0');
        // force to hopefully work around apparent Cypress SVG issue
        cy.get('image[title="Lights out in tunnel"]').last().click({force: true});
        cy.wait('@show-report');
        cy.get('#side-report').contains('Get updates').click();
        cy.contains('Receive email when updates are left').should('be.visible');
        cy.get('#side-report').contains('Get updates').click();
        cy.contains('Receive email when updates are left').should('not.be.visible');
    });

    it('works on an around page', function() {
        cy.visit('/around?lon=-2.295894&lat=51.526877&zoom=0');
        cy.contains('Get updates').click();
        cy.contains('Which problems do you want alerts about?').should('be.visible');
        cy.contains('Get updates').click();
        cy.contains('Which problems do you want alerts about?').should('not.be.visible');
    });
});
