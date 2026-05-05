it('toggles the aerial map', function() {
    cy.visit('http://northumberland.localhost:3001/');
    cy.contains('Northumberland');

    cy.get('[name=pc]').type(Cypress.expose('postcode'));
    cy.get('[name=pc]').parents('form').submit();
    cy.get('.map-layer-toggle').click();
    cy.get('.map-layer-toggle').should('have.class', 'roads');
    cy.get('.map-layer-toggle').click();
    cy.get('.map-layer-toggle').should('have.class', 'aerial');
});
