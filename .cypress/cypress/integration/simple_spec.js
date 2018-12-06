describe('Clicking the map', function() {
    before(function(){
        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
    });

    it('allows me to report a new problem', function() {
        cy.url().should('include', '/around');
        cy.get('#map_box').click(200, 200);
        cy.get('[name=title]').type('Title');
        cy.get('[name=detail]').type('Detail');
        cy.get('.js-new-report-user-show').click();
        cy.get('.js-new-report-show-sign-in').should('be.visible').click();
        cy.get('#form_username_sign_in').type('user@example.org');
        cy.get('[name=password_sign_in]').type('password');
        cy.get('[name=password_sign_in]').parents('form').submit();
        cy.get('#map_sidebar').should('contain', 'check and confirm your details');
        cy.get('#map_sidebar').parents('form').submit();
        cy.get('body').should('contain', 'Thank you for reporting this issue');
    });
});

describe('Leaving updates', function() {
    function leave_update() {
        cy.get('[name=update]').type('Update');
        cy.get('.js-new-report-user-show:last').click();
        cy.get('.js-new-report-show-sign-in:last').should('be.visible').click();
        // [id=]:last due to #2341
        cy.get('[id=form_username_sign_in]:last').type('user@example.org');
        cy.get('[name=password_sign_in]:last').type('password');
        cy.get('[name=password_sign_in]:last').parents('form:first').submit();
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
        cy.visit('/around?lon=-2.295894&lat=51.526877&zoom=6');
        // force to hopefully work around apparent Cypress SVG issue
        cy.get('image[title="Lights out in tunnel"]:last').click({force: true});
        cy.wait('@show-report');
        leave_update();
    });
});

describe('Clicking the "big green banner" on a map page', function() {
    before(function() {
        cy.visit('/');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.get('.big-green-banner').click();
    });

    it('begins a new report', function() {
        cy.url().should('include', '/report/new');
        cy.get('#form_title').should('be.visible');
    });
});
