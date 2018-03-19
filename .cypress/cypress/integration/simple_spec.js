describe('My First Test', function() {
    it('Visits the home page', function() {
        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type('BS10 5EE');
        cy.get('#postcodeForm').submit();
        cy.url().should('include', '/around');
        cy.get('#map_box').click(200, 200);
        cy.get('[name=title]').type('Title');
        cy.get('[name=detail]').type('Detail');
        cy.get('[name=username]').type('user@example.org');
        cy.get('[name=password_sign_in]').type('password');
        cy.get('form').submit();
        cy.get('form').submit();
    });
});

describe('Clicking the "big green banner" on a map page', function() {
    before(function() {
        cy.visit('/');
        cy.get('[name=pc]').type('BS10 5EE');
        cy.get('#postcodeForm').submit();
        cy.get('.big-green-banner').click();
    });

    it('begins a new report', function() {
        cy.url().should('include', '/report/new');
        cy.get('#form_title').should('be.visible');
    });
});
