describe('When you look at the Hackney site', function() {

  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.visit('http://hackney.localhost:3001/');
    cy.contains('Hackney Council');
    cy.should('not.contain', 'Hackney Borough');
    cy.get('[name=pc]').type('E8 1DY');
    cy.get('[name=pc]').parents('form').submit();
  });

  it('uses the correct name', function() {
    cy.get('#map_box').click();
    cy.wait('@report-ajax');
    cy.pickCategory('Potholes');
    cy.contains('sent to Hackney Council');
  });

  it('only allows 256 chars in description', function() {
    cy.get('#map_box').click();
    cy.wait('@report-ajax');
    cy.pickCategory('Potholes');
    cy.contains('sent to Hackney Council');
    cy.nextPageReporting();
    // photos page
    cy.nextPageReporting();
    cy.get('#form_detail').type('a'.repeat(260));
    cy.get('#form_detail').invoke('val').then(function(val){
        expect(val.length).to.be.at.most(256);
    });
    cy.get('#form_detail').invoke('val', 'a'.repeat(260));
    cy.get('#form_detail').invoke('val').then(function(val){
        expect(val.length).to.equal(260);
    });
    cy.nextPageReporting();
    cy.contains("Reports are limited to 256 characters in length. Please shorten your report");

  });
});
