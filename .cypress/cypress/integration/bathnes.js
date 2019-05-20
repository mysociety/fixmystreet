it('loads the right front page', function() {
    cy.visit('http://bathnes.localhost:3001/');
    cy.contains('North East Somerset');
});
