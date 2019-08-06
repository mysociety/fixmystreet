Cypress.Commands.add('cleanUpXHR', function() {
    cy.visit('/404', { failOnStatusCode: false });
});

describe('Staff user tests', function() {
    it('report as defaults to body', function() {
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
        cy.get('[name=form_as]').should('have.value', 'body');
        cy.cleanUpXHR();
    });

    it('report title and detail are correctly prefilled', function() {
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
        cy.get('select:eq(3)').select('Graffiti');
        cy.get('[name=title]').should('have.value', 'A Graffiti problem has been found');
        cy.get('[name=detail]').should('have.value', 'A Graffiti problem has been found by Borsetshire County Council');
        cy.cleanUpXHR();
    });
});
