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
    cy.get('.olMap'); // Make sure map is loaded before testing its layers
    cy.window().then(function(win){
        var llpg = 0;
        win.fixmystreet.map.layers.forEach(function(lyr) {
            if (lyr.fixmystreet && lyr.fixmystreet.http_options && lyr.fixmystreet.http_options.params && lyr.fixmystreet.http_options.params.TYPENAME === 'LLPG') {
                llpg++;
            }
        });
        expect(llpg).to.equal(1);
    });
});

it('uses the Curo Group housing layer correctly', function() {
    cy.server();
    cy.route(/.*?data\.bathnes\.gov\.uk.*?fms:curo_land_registry.*/, 'fixture:banes-caro-group-housing-layer.json').as('banes-caro-group-housing-layer-tilma');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.visit('http://bathnes.localhost:3001/report/new?longitude=-2.359276&latitude=51.379009');
    cy.contains('Bath & North East Somerset Council');
    cy.wait('@banes-caro-group-housing-layer-tilma');
    cy.wait('@report-ajax');
    cy.pickCategory('Dog fouling');
    cy.get('.pre-button-messaging').contains('Maintained by Curo Group').should('be.visible');
});

it('handles code names with spaces without error', function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.visit('http://bathnes.localhost:3001/report/new?longitude=-2.359276&latitude=51.379009');
    cy.wait('@report-ajax');
    cy.get('input[value="Abandoned vehicles"]').click();
    cy.get('input[value="Blocked drain"]').click();
    cy.get('input[value="Abandoned vehicles"]').click();
    cy.contains('Not maintained by Bath & North East Somerset Council');
});
