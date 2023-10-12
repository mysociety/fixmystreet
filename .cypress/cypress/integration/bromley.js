describe('Bromley cobrand', function() {

  beforeEach(function() {
    cy.server();
    cy.route('**mapserver/bromley*Streetlights*', 'fixture:bromley-lights.xml').as('lights');
    cy.route('**mapserver/bromley*PROW*', 'fixture:bromley-prow.xml').as('prow');
    cy.route('**mapserver/bromley*Crystal_Palace*', 'fixture:crystal_palace_park.xml').as('crystal');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.viewport(480, 800);
    cy.visit('http://bromley.localhost:3001/report/new?latitude=51.4021&longitude=0.01578');
    cy.contains('Bromley');
    cy.wait('@prow');
    cy.wait('@crystal');
    cy.wait('@report-ajax');
    cy.get('#mob_ok').click();
  });

  it('fills the right of way field', function() {
    cy.pickCategory('Street Lighting and Road Signs');
    cy.nextPageReporting();
    cy.pickSubcategory('Street Lighting and Road Signs', 'Lamp Column Damaged');
    cy.get('#form_prow_reference').should('have.value', 'FP111');
  });

  it('does not display asset based upon extra question', function() {
    cy.pickCategory('Street Lighting and Road Signs');
    cy.nextPageReporting();
    cy.pickSubcategory('Street Lighting and Road Signs', 'Sign Light Not Working');
    // https://stackoverflow.com/questions/47295287/cypress-io-assert-no-xhr-requests-to-url
    cy.on('fail', function(err) {
      expect(err.message).to.include('No request ever occurred.');
      return false;
    });
    cy.wait('@lights', { timeout: 0 }).then(function(xhr) { throw new Error('Unexpected API call.'); });
  });

  it('displays assets based upon extra question', function() {
    cy.pickCategory('Street Lighting and Road Signs');
    cy.nextPageReporting();
    cy.pickSubcategory('Street Lighting and Road Signs', 'Lamp Column Damaged');
    cy.wait('@lights');
    cy.nextPageReporting();
    cy.get('.mobile-map-banner').should('be.visible');
  });

  it('adds stopper for Crystal Palace Park', function() {
    cy.visit('http://bromley.localhost:3001/report/new?longitude=-0.064555&latitude=51.422382');
    cy.wait('@crystal');
    cy.wait('@report-ajax');
    cy.contains('transferred to the Crystal Palace Park Trust');
    cy.get('#mob_ok').should('not.be.visible');
  });

});
