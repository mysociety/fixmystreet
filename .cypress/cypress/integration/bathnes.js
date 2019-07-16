it('loads the right front page', function() {
    cy.visit('http://bathnes.localhost:3001/');
    cy.contains('North East Somerset');
});

it('loads the staff layer correctly', function() {
    cy.request({
      method: 'POST',
      url: 'http://bathnes.localhost:3001/auth?r=/',
      form: true,
      body: { username: 'admin@example.org', password_sign_in: 'password' }
    });
    cy.visit('http://bathnes.localhost:3001/');
    cy.contains('Your account');
    cy.get('[name=pc]').type(Cypress.env('postcode'));
    cy.get('[name=pc]').parents('form').submit();
    cy.url().should('include', '/around');
    cy.window().its('fixmystreet.maps').should('have.property', 'banes_defaults');
    cy.window().then(function(win){
        var llpg = 0;
        win.fixmystreet.map.layers.forEach(function(lyr) {
            if (lyr.fixmystreet && lyr.fixmystreet.http_options.params.TYPENAME === 'LLPG') {
                llpg++;
            }
        });
        expect(llpg).to.equal(1);
    });
});
