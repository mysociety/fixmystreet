// See https://github.com/cypress-io/cypress/issues/761 - Cypress dies if we
// go straight to the next test with an XHR in progress. So visit a 404 page
// to cancel anything in progress.
Cypress.Commands.add('cleanUpXHR', function() {
    cy.visit('/404', { failOnStatusCode: false });
});

describe('Regression tests', function() {
    it('Shows the sub-map links after clicking Try again', function() {
        cy.viewport(480, 800);
        cy.visit('/around?pc=' + Cypress.env('postcode') + '&js=1');
        cy.get('#map_box').click(200, 200);
        cy.get('#problems_nearby').click();
        cy.get('#sub_map_links').should('be.visible');
        cy.cleanUpXHR();
    });
    it('Does not fade on new pin hover', function() {
        cy.visit('/around?pc=' + Cypress.env('postcode') + '&js=1');
        cy.get('#map_box').click(200, 200);
        cy.get('#map_box image').last().trigger('mousemove').should('have.css', 'opacity', '1');
    });
    it('Does not hide the new report pin even if you click really quick', function() {
        cy.visit('/around?pc=' + Cypress.env('postcode') + '&js=1');
        cy.get('#map_box').click(200, 200);
        cy.get('#loading-indicator').should('be.hidden');
        cy.get('#map_box image').should('be.visible');
    });
    it('Does not escape HTML entities in the title', function() {
        cy.server();
        cy.route('/around\?ajax*').as('update-results');
        cy.request({
          method: 'POST',
          url: '/auth?r=/',
          form: true,
          body: { username: 'cs@example.org', password_sign_in: 'password' }
        });
        cy.visit('/report/1/moderate');
        cy.get('[name=problem_title]').clear().type('M&S "brill" says <glob>').parents('form').submit();
        cy.title().should('contain', 'M&S "brill" says <glob>');
        cy.contains('Problems nearby').click();
        cy.wait('@update-results');
        cy.get('#map_sidebar').contains('M&S').click();
        cy.title().should('contain', 'M&S "brill" says <glob>');
    });

    it('hides the report when going from around to report to form', function() {
        cy.server();
        cy.route('/report/*').as('show-report');
        cy.visit('/around?lon=-2.295894&lat=51.526877&zoom=6');
        // force to hopefully work around apparent Cypress SVG issue
        cy.get('image[title="Lights out in tunnel"]:last').click({force: true});
        cy.wait('@show-report');
        cy.get('.report-a-problem-btn').eq(0).should('contain', 'Report another problem here').click();
        cy.get('.content').should('not.contain', 'toddler');
    });

    it('has the correct send-to text at all times', function() {
      cy.server();
      cy.route('/report/new/ajax*').as('report-ajax');
      cy.visit('/');
      cy.get('[name=pc]').type('NN1 1NS');
      cy.get('[name=pc]').parents('form').submit();

      cy.get('#map_box').click();
      cy.wait('@report-ajax');
      cy.get('[id=category_group]').select('Graffiti');
      cy.contains(/These will be sent to Northampton Borough Council and also/);

      cy.get('#map_box').click(200, 200);
      cy.wait('@report-ajax');
      cy.contains(/These will be sent to Northampton Borough Council and also/);
    });

    it('remembers extra fields when you sign in during reporting', function() {
      cy.server();
      cy.route('/report/new/ajax*').as('report-ajax');
      cy.visit('/around?lon=-2.295894&lat=51.526877&zoom=6&js=1');
      cy.get('#map_box').click();
      cy.wait('@report-ajax');
      cy.get('[id=category_group]').select('Licensing');
      cy.get('[id=subcategory_Licensing]').select('Skips');
      cy.get('[name=title]').type('Title');
      cy.get('[name=detail]').type('Detail');
      cy.get('[name=start_date').type('2019-01-01');
      cy.get('.js-new-report-user-show').click();
      cy.get('.js-new-report-show-sign-in').should('be.visible').click();
      cy.get('#form_username_sign_in').type('user@example.org');
      cy.get('[name=password_sign_in]').type('password');
      cy.get('[name=password_sign_in]').parents('form').submit();
      cy.get('#map_sidebar').should('contain', 'check and confirm your details');
      cy.wait('@report-ajax');
      cy.get('#form_start_date').should('have.value', '2019-01-01');
    });

});
