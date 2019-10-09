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
    cy.get('select:eq(4)').select('Potholes');
    cy.contains('sent to Hackney Council');
  });
});
