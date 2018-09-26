// See https://github.com/cypress-io/cypress/issues/761 - Cypress dies if we
// go straight to the next test with an XHR in progress. So visit a 404 page
// to cancel anything in progress.
Cypress.Commands.add('cleanUpXHR', function() {
    cy.visit('/404', { failOnStatusCode: false });
});

describe('Front page responsive design tests', function() {
    it('Shows correct things on mobile', function() {
        cy.viewport(480, 800);
        cy.visit('/');
        cy.get('a#report-cta').should('be.visible');
    });

    it('Shows correct things on tablet', function() {
        cy.viewport(800, 800);
        cy.visit('/');
        cy.get('a#report-cta').should('not.be.visible');
    });

    it('Shows correct things on desktop', function() {
        cy.viewport(1024, 800);
        cy.visit('/');
        cy.get('a#report-cta').should('not.be.visible');
    });
});

describe('Around page responsive design tests', function() {
    it('Shows correct things on mobile', function() {
        cy.viewport(480, 800);
        cy.visit('/around?pc=' + Cypress.env('postcode') + '&js=1');
        cy.get('.mobile-map-banner').should('be.visible');
        cy.get('#sub_map_links').should('be.visible');
        cy.get('#map_links_toggle').should('not.be.visible');
        cy.get('#map_box').click(200, 200);
        cy.get('#sub_map_links').should('not.be.visible');
        cy.get('#try_again').should('be.visible');
        cy.get('#mob_ok').click();
        cy.cleanUpXHR();
    });

    it('Shows correct things on tablet', function() {
        cy.viewport(800, 800);
        cy.visit('/around?pc=' + Cypress.env('postcode') + '&js=1');
        cy.get('.mobile-map-banner').should('not.be.visible');
        cy.get('#map_sidebar').should('be.visible');
        cy.get('#side-form').should('not.be.visible');
        cy.get('#sub_map_links').should('be.visible');
        cy.get('#map_links_toggle').should('be.visible');
        cy.get('#map_box').click(200, 200);
        cy.get('#sub_map_links').should('be.visible');
        cy.get('#side-form').should('be.visible');
        cy.cleanUpXHR();
    });

    it('Shows correct things on desktop', function() {
        cy.viewport(1024, 800);
        cy.visit('/around?pc=' + Cypress.env('postcode') + '&js=1');
        cy.get('.mobile-map-banner').should('not.be.visible');
        cy.get('#map_sidebar').should('be.visible');
        cy.get('#sub_map_links').should('be.visible');
        cy.get('#map_links_toggle').should('be.visible');
        cy.get('#side-form').should('not.be.visible');
        cy.get('#map_box').click(200, 200);
        cy.get('#sub_map_links').should('be.visible');
        cy.get('#side-form').should('be.visible');
        cy.cleanUpXHR();
    });
});
