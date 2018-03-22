// See https://github.com/cypress-io/cypress/issues/761 - Cypress dies if we
// go straight to the next test with an XHR in progress. So visit a 404 page
// to cancel anything in progress.
Cypress.Commands.add('cleanUpXHR', function() {
    cy.visit('/404', { failOnStatusCode: false });
});

describe('Regression tests', function() {
    it('Shows the sub-map links after clicking Try again', function() {
        cy.viewport(480, 800);
        cy.visit('/around?pc=BS10+5EE&js=1');
        cy.get('#map_box').click(200, 200);
        cy.get('#try_again').click();
        cy.get('#sub_map_links').should('be.visible');
        cy.cleanUpXHR();
    });
    it('Does not fade on new pin hover', function() {
        cy.visit('/around?pc=BS10+5EE&js=1');
        cy.get('#map_box').click(200, 200);
        cy.get('#map_box image').last().trigger('mousemove').should('have.css', 'opacity', '1');
    });
    it('Does not hide the new report pin even if you click really quick', function() {
        cy.visit('/around?pc=BS10+5EE&js=1');
        cy.get('#map_box').click(200, 200);
        cy.get('#loading-indicator').should('be.hidden');
        cy.get('#map_box image').should('be.visible');
    });
});
