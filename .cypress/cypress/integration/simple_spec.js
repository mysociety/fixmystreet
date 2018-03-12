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
