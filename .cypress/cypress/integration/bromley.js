describe('Bromley cobrand', function() {

  beforeEach(function() {
    cy.server();
    cy.route('**mapserver/bromley*Streetlights*', 'fixture:bromley-lights.xml').as('lights');
    cy.route('**mapserver/bromley*PROW*', 'fixture:bromley-prow.xml').as('prow');
    cy.route('**mapserver/bromley*Crystal_Palace*', 'fixture:crystal_palace_park.xml').as('crystal');
    cy.route('**mapserver/bromley*National_Sports*', 'fixture:national_sports_centre.xml').as('sport_centre');
    cy.route('**mapserver/bromley*Parks_Open_Spaces*', 'fixture:bromley-parks.xml').as('parks');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.viewport(480, 800);
  });

  describe('category asset tests', function() {
    beforeEach(function() {
      cy.visit('http://bromley.localhost:3001/report/new?latitude=51.4021&longitude=0.01578');
      cy.contains('Bromley');
      cy.wait('@report-ajax');
      cy.get('#mob_ok').click();
    });

    it('fills the right of way field', function() {
      cy.wait('@prow');
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

    it('sets extra cobrand owner field when streetlight asset selected', function() {
      cy.pickCategory('Street Lighting and Road Signs');
      cy.nextPageReporting();
      cy.pickSubcategory('Street Lighting and Road Signs', 'Lamp Column Damaged');
      cy.wait('@lights');
      cy.nextPageReporting();
      cy.get('.mobile-map-banner').should('be.visible');
      cy.get('#form_fms_layer_owner').should('have.value', '');
      cy.visit('http://bromley.localhost:3001/report/new?longitude=0.022775&latitude=51.398387');
      cy.wait('@report-ajax');
      cy.get('#mob_ok').click();
      cy.pickCategory('Street Lighting and Road Signs');
      cy.nextPageReporting();
      cy.pickSubcategory('Street Lighting and Road Signs', 'Lamp Column Damaged');
      cy.wait('@lights');
      cy.get('#form_fms_layer_owner').should('have.value', 'bromley');
    });
  });

  describe('location asset tests', function() {
    it('adds stopper for Crystal Palace Park', function() {
      cy.visit('http://bromley.localhost:3001/report/new?longitude=-0.064555&latitude=51.422382');
      cy.wait('@crystal');
      cy.contains('transferred to the Crystal Palace Park Trust');
      cy.get('#mob_ok').should('not.be.visible');
    });

    it('adds stopper for National Sports Centre', function() {
      cy.visit('http://bromley.localhost:3001/report/new?longitude=-0.071410&latitude=51.419275');
      cy.wait('@sport_centre');
      cy.contains('responsibility of the National Sports Centre');
      cy.get('#mob_ok').should('not.be.visible');
    });

    it('adds post category message for Street categories within a park', function() {
      cy.visit('http://bromley.localhost:3001/report/new?longitude=0.007803&latitude=51.403986');
      cy.wait('@report-ajax');
      cy.get('#mob_ok').click();
      cy.pickCategory('Street Cleansing');
      cy.wait('@parks');
      cy.contains('We’ve noticed that you’ve selected a Streets category but that your map pin is located within a park').should('be.visible');
    });

    it('adds post category message for Park and Greenspace categories not in a park', function() {
      cy.visit('http://bromley.localhost:3001/report/new?latitude=51.4021&longitude=0.01578');
      cy.wait('@report-ajax');
      cy.get('#mob_ok').click();
      cy.pickCategory('Parks and Greenspace');
      cy.wait('@parks');
      cy.contains('We’ve noticed that you’ve selected a Parks and Greenspace category but that your map pin isn’t located within a park').should('be.visible');
    });
  });
});
