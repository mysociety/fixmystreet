describe('Bromley cobrand', function() {

  beforeEach(function() {
    cy.server();
    cy.route('**mapserver/bromley*Streetlights*', 'fixture:bromley-lights.xml').as('lights');
    cy.route('**mapserver/bromley*PROW*', 'fixture:bromley-prow.xml').as('prow');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.viewport(480, 800);
    cy.visit('http://bromley.localhost:3001/report/new?latitude=51.4021&longitude=0.01578');
    cy.contains('Bromley');
    cy.wait('@prow');
    cy.wait('@report-ajax');
    cy.get('#mob_ok').click();
  });

  it('fills the right of way field', function() {
    cy.get('select').eq(1).select('Street Lighting and Road Signs');
    cy.get('#form_prow_reference').should('have.value', 'FP111');
  });

  it('does not display asset based upon extra question', function() {
    cy.get('select').eq(1).select('Street Lighting and Road Signs');
    cy.get('.js-reporting-page--next:visible').click();
    cy.get('select').eq(2).select('Non-asset');
    // https://stackoverflow.com/questions/47295287/cypress-io-assert-no-xhr-requests-to-url
    cy.on('fail', function(err) {
      expect(err.message).to.include('No request ever occurred.');
      return false;
    });
    cy.wait('@lights', { timeout: 0 }).then(function(xhr) { throw new Error('Unexpected API call.'); });
  });

  it('displays assets based upon extra question', function() {
    cy.get('select').eq(1).select('Street Lighting and Road Signs');
    cy.get('.js-reporting-page--next:visible').click();
    cy.get('select').eq(2).select('On in day');
    cy.wait('@lights');
    cy.get('.js-reporting-page--next:visible').click();
    cy.get('.mobile-map-banner').should('be.visible');
  });

});
