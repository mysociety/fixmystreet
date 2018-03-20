describe('Clicking the map', function() {
    before(function(){
        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type('BS10 5EE');
        cy.get('[name=pc]').parents('form').submit();
    });

    it('allows me to report a new problem', function() {
        cy.url().should('include', '/around');
        cy.get('#map_box').click(200, 200);
        cy.get('[name=title]').type('Title');
        cy.get('[name=detail]').type('Detail');
        cy.get('[name=username]').type('user@example.org');
        cy.get('[name=password_sign_in]').type('password');
        cy.get('[name=password_sign_in]').parents('form').submit();
        cy.get('#map_sidebar').should('contain', 'check and confirm your details');
        cy.get('#map_sidebar').parents('form').submit();
        cy.get('body').should('contain', 'Thank you for reporting this issue');
    });
});

describe('Clicking the "big green banner" on a map page', function() {
    before(function() {
        cy.visit('/');
        cy.get('[name=pc]').type('BS10 5EE');
        cy.get('[name=pc]').parents('form').submit();
        cy.get('.big-green-banner').click();
    });

    it('begins a new report', function() {
        cy.url().should('include', '/report/new');
        cy.get('#form_title').should('be.visible');
    });
});
