describe('When you look at the Island Roads site', function() {

  beforeEach(function() {
    cy.server();
    cy.fixture('roads.xml');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.visit('http://isleofwight.localhost:3001/');
    cy.contains('Island Roads');
    cy.get('[name=pc]').type('PO30 5XJ');
    cy.get('[name=pc]').parents('form').submit();
  });

  it('uses the correct name', function() {
    cy.get('#map_box').click();
    cy.wait('@report-ajax');
    cy.get('select:eq(4)').select('Potholes');
    cy.contains('sent to Island Roads');
    cy.get('select:eq(4)').select('Private');
    cy.contains('sent to Island Roads');
    cy.get('select:eq(4)').select('Extra');
    cy.contains('Help Island Roads');
  });
});
