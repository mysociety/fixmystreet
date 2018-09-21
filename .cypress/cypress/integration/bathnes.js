var cobrand = Cypress.env('cobrand');
var only_or_skip = (cobrand == 'bathnes') ? describe.only : describe.skip;

only_or_skip('Bath cobrand specific testing', function() {

    it('loads the right front page', function() {
        cy.visit('/');
        cy.contains('North East Somerset');
    });
});
