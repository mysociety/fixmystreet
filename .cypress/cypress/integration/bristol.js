describe('Abandoned vehicle behaviour', function() {
  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('/around\?ajax*').as('update-results');
    cy.visit('http://bristol.localhost:3001/');
    cy.contains('Bristol');
    cy.get('[name=pc]').type('BS10 5EE');
    cy.get('[name=pc]').parents('form').submit();
    cy.wait('@update-results');
    cy.get('#map_box').click(322, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Abandoned vehicle');
    cy.nextPageReporting();
    cy.pickSubcategory('Abandoned vehicle', 'A vehicle left on public road for over two months');
    cy.nextPageReporting();
  });

  it('No reg plate', function() {
    cy.get('.js-reporting-page--active').contains('No').click();
    cy.nextPageReporting();
    cy.get('[name=NE02]').should('have.value', 'Not known');
  });

  it('Said yes but no reg plate', function() {
    cy.get('.js-reporting-page--active').contains('Yes').click();
    cy.nextPageReporting();
    cy.contains('This field is required');
  });

  it('Gave an okay reg plate', function() {
    cy.route('POST', '/report/dvla', 'fixture:bucks_dvla_ok.json').as('dvla');
    cy.get('.js-reporting-page--active').contains('Yes').click();
    cy.get('[name=dvla_reg]').type('G00D');
    cy.nextPageReporting();
    cy.wait('@dvla');
    cy.contains('White Audi c, Petrol, 2016');
    cy.contains('that are taxed or have a valid MOT');
  });

  it('Gave an untaxed reg plate', function() {
    cy.route('POST', '/report/dvla', 'fixture:bucks_dvla_notok.json').as('dvla');
    cy.get('.js-reporting-page--active').contains('Yes').click();
    cy.get('[name=dvla_reg]').type('B4D');
    cy.nextPageReporting();
    cy.wait('@dvla');
    cy.get('[name=NE02]').should('have.value', 'B4D');
    cy.get('[name=NE01]').should('have.value', 'N');
    cy.get('[name=NE03]').should('have.value', 'MM');
    cy.get('[name=NE04]').should('have.value', 'Kawasaki');
    cy.get('[name=NE07]').should('have.value', 'Black');
  });
});
