describe('When you look at the Island Roads site', function() {

  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.visit('http://isleofwight.localhost:3001/');
    cy.contains('Island Roads');
    cy.get('[name=pc]').type('PO30 5XJ');
    cy.get('[name=pc]').parents('form').submit();
  });

  it('uses the correct name', function() {
    cy.get('#map_box').click();
    cy.wait('@report-ajax');
    cy.pickCategory('Potholes');
    cy.nextPageReporting();
    cy.nextPageReporting(); // Photos
    cy.contains('sent to Island Roads').should('be.visible');
    cy.go('back');
    cy.go('back');
    cy.pickCategory('Private');
    cy.nextPageReporting();
    cy.nextPageReporting(); // Photos
    cy.contains('sent to Island Roads').should('be.visible');
    cy.go('back');
    cy.go('back');
    cy.pickCategory('Extra');
    cy.nextPageReporting();
    cy.contains('Help Island Roads').should('be.visible');
  });

  it('displays nearby roadworks', function() {
    cy.route('/streetmanager.php**', 'fixture:iow_roadworks.json').as('roadworks');
    cy.visit('http://isleofwight.localhost:3001/');
    cy.get('[name=pc]').type('PO30 5XJ');
    cy.get('[name=pc]').parents('form').submit();
    cy.get('#map_box').click();
    cy.wait('@report-ajax');
    cy.pickCategory('Potholes');
    cy.nextPageReporting();
    cy.wait('@roadworks');
    cy.contains('Roadworks are scheduled near this location').should('be.visible');
    cy.contains('Parapet improvement').should('be.visible');
  });
});
