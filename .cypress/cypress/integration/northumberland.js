it('loads the right front page', function() {
    cy.visit('http://northumberland.localhost:3001/');
    cy.contains('Northumberland');
});

it('toggles the aerial map', function() {
    cy.get('[name=pc]').type(Cypress.env('postcode'));
    cy.get('[name=pc]').parents('form').submit();
    cy.get('.map-layer-toggle').click();
    cy.get('.map-layer-toggle').should('have.class', 'roads');
    cy.get('.map-layer-toggle').click();
    cy.get('.map-layer-toggle').should('have.class', 'aerial');
});

describe('Abandoned vehicle behaviour', function() {
  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('/around\?ajax*').as('update-results');
    cy.visit('http://northumberland.localhost:3001/');
    cy.contains('Northumberland');
    cy.get('[name=pc]').type('NE61 1BE');
    cy.get('[name=pc]').parents('form').submit();
    cy.wait('@update-results');
    cy.get('#map_box').click(322, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Vehicle abandoned on your property');
    cy.nextPageReporting();
  });

  it('No reg plate', function() {
    cy.get('.js-reporting-page--active').contains('No').click();
    cy.nextPageReporting();
    cy.get('[name=question]').should('have.value', '');
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
    cy.contains('White Audi, Petrol, 2016');
    cy.contains('that are taxed or have a valid MOT');
  });

  it('Gave an untaxed reg plate', function() {
    cy.route('POST', '/report/dvla', 'fixture:bucks_dvla_notok.json').as('dvla');
    cy.get('.js-reporting-page--active').contains('Yes').click();
    cy.get('[name=dvla_reg]').type('B4D');
    cy.nextPageReporting();
    cy.wait('@dvla');
    cy.get('[name=question]').invoke('val').should('include', 'B4D');
  });
});
