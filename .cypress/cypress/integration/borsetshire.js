it('loads the right front page', function() {
    cy.visit('http://borsetshire.localhost:3001/');
    cy.contains('Borsetshire');
});

it('logs in without fuss', function() {
    cy.contains('Sign in').click();
    cy.contains('Customer service').click();
    cy.url().should('include', '/reports');

    cy.contains('Your account').click();
    cy.contains('Sign out').click();
    cy.contains('Sign in').click();
    cy.contains('Inspector').click();
    cy.url().should('include', '/my/planned');

    cy.visit('http://borsetshire.localhost:3001/auth');
    cy.get('[name=username]').type('super@example.org');
    cy.contains('Sign in with a password').click();
    cy.get('[name=password_sign_in]').type('password');
    cy.get('[name=sign_in_by_password]').last().click();
    cy.url().should('include', '/admin');
});
