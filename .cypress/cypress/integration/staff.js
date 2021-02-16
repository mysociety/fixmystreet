Cypress.Commands.add('cleanUpXHR', function() {
    cy.visit('/404', { failOnStatusCode: false });
});

describe('Staff user tests', function() {
    beforeEach(function() {
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
        cy.request({
          method: 'POST',
          url: '/auth?r=/',
          form: true,
          body: { username: 'cs_full@example.org', password_sign_in: 'password' }
        });
        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.url().should('include', '/around');
        cy.get('#map_box').click(240, 249);
        cy.wait('@report-ajax');
    });

    it('report as defaults to body', function() {
        cy.get('[name=form_as]').should('have.value', 'body');
        cy.cleanUpXHR();
    });

    it('report title and detail are correctly prefilled', function() {
        cy.pickCategory('Graffiti (offensive)');
        cy.get('[name=title]').should('have.value', 'A Graffiti (offensive) problem has been found');
        cy.get('[name=detail]').should('have.value', 'A Graffiti (offensive) problem has been found by Borsetshire County Council');
        cy.cleanUpXHR();
    });

    it('does not let staff update their name, phone or email address whilst reporting or updating', function() {
        // Lest CS staff forget to select 'report as another user' and type the reporter's details over their own.

        cy.pickCategory('Flytipping');
        // Skip through to about you page
        cy.nextPageReporting();
        cy.nextPageReporting();
        cy.nextPageReporting();

        // about you page
        cy.get('#form_as').select('myself');
        cy.get('[name=username]').should('be.disabled'); // (already protected)
        cy.get('[name=phone]').should('be.disabled');
        cy.get('[name=name]').should('have.attr', 'readonly');
        cy.get('#map_sidebar').parents('form').submit();

        // now check update page (going via 'Your account')
        // (clicking on h1 conf link leaves staff fields still locked, so test passes in error)
        cy.visit('/my');
        cy.get('#js-reports-list li:first-child').click();

        // update about you
        cy.get('#form_update').type("this is an update");
        cy.get('button.js-reporting-page--next').click();
        cy.get('#form_as').select('myself');
        cy.get('[name=username]').should('be.disabled'); // (already protected)
        cy.get('[name=name]').should('have.attr', 'readonly');
        cy.get('input[name=submit_register]').click();
    });
});
