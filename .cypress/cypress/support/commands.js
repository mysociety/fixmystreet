// jshint esversion: 6
Cypress.Commands.add('pickCategory', function(option) {
    cy.get('#category_group').select(option);
});
Cypress.Commands.add('pickSubcategory', function(option, selector) {
    if (!selector) {
        selector = '.js-subcategory:visible';
    }
    cy.get(selector).select(option);
});
Cypress.Commands.add('nextPageReporting', function() {
    cy.get('.js-reporting-page--active:visible .js-reporting-page--next').click();
});
