it('loads the right front page', function() {
    cy.visit('http://borsetshire.localhost:3001/');
    cy.contains('Borsetshire');
});

it('logs in without fuss', function() {
    cy.server();
    cy.route('/mapit/area/*').as('get-geometry');

    cy.contains('Sign in').click();
    cy.contains('Customer service').click();
    cy.url().should('include', '/reports');
    cy.wait('@get-geometry');

    cy.contains('Your account').click();
    cy.contains('Sign out').click();
    cy.contains('Sign in').click();
    cy.contains('Inspector').click();
    cy.url().should('include', '/my/planned');
    // Wait for offline stuff, which can take time
    cy.contains('Save to this device for offline use').should('be.visible').click();
    cy.get('.top_banner--offline', { timeout: 10000 }).contains('Reports saved offline', { timeout: 10000 });
    cy.contains('Save to this device for offline use').should('not.be.visible');

    cy.contains('Your account').click();
    cy.contains('Sign out').click();
    cy.contains('Sign in').click();
    cy.get('[name=username]').type('super@example.org');
    cy.contains('Sign in with a password').click();
    cy.get('[name=password_sign_in]').type('password');
    cy.get('[name=sign_in_by_password]').last().click();
    cy.url().should('include', '/admin');
});
