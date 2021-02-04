describe('Westminster cobrand', function() {

  beforeEach(function() {
    cy.server();
    cy.route('**/westminster.assets/40/*', 'fixture:westminster-usrn.json');
    cy.route("**/westminster.assets/25/*PARENTUPRN='XXXX'*", 'fixture:westminster-uprn.json').as('uprn');
    cy.route("**/westminster.assets/25/*PARENTUPRN='1000123'*PARENTUPRN='1000234'", 'fixture:westminster-uprn-0123.json');
    cy.route('**/westminster.assets/46/*', 'fixture:westminster-nameplates.json').as('nameplates');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.viewport(480, 800);
    cy.visit('http://westminster.localhost:3001/report/new?latitude=51.501009&longitude=-0.141588');
    cy.contains('Westminster');
    cy.wait('@report-ajax');
    cy.get('#mob_ok').click();
  });

  it('checks asset fetching when extra question answered', function() {
    cy.pickCategory('Signs and bollards');
    cy.get('#form_USRN').should('have.value', 'USRN123');
    cy.nextPageReporting();
    cy.pickSubcategory('Nameplates', '#form_featuretypecode');
    cy.wait('@nameplates');
    cy.nextPageReporting();
    cy.get('.mobile-map-banner').should('be.visible');
  });

  it('checks UPRN fetching', function() {
    cy.pickCategory('Damaged, dirty, or missing bin');
    cy.nextPageReporting();
    cy.pickSubcategory('Request new bin', '#form_bin_type');
    cy.wait('@uprn');
    cy.nextPageReporting();
    cy.get('.mobile-map-banner').should('be.visible');
    cy.get('#mob_ok').click();
    cy.get('#uprn').should('be.visible');
    cy.get('#uprn').contains('7 Address');
    cy.get('#uprn').contains('11-12 Address');
    cy.get('#uprn').contains('7b Address');
    cy.get('#uprn').should('not.contain', '4 Address');
  });

});
