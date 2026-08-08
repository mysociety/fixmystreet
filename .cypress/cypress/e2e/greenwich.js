// See bristol.js for full testing of dvla

describe('Abandoned vehicle behaviour', function() {
  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('/around\?ajax*').as('update-results');
    cy.visit('http://greenwich.localhost:3001/');
    cy.contains('Greenwich');
    cy.visit('http://greenwich.localhost:3001/report/new?longitude=0.00754&latitude=51.48593');
    cy.wait('@report-ajax');
    cy.pickCategory('Abandoned vehicles');
    cy.nextPageReporting();
  });

  it('selects no for reg plate', function() {
    cy.get('.js-reporting-page--active').contains('No').click();
    cy.nextPageReporting();
    cy.get('[name=vehicle_registration]').should('have.value', 'Not known');
  });

  it('gave an okay reg plate', function() {
    cy.route('POST', '/report/dvla', 'fixture:bucks_dvla_ok.json').as('dvla');
    cy.get('.js-reporting-page--active').contains('Yes').click();
    cy.get('[name=dvla_reg]').type('G00D');
    cy.nextPageReporting();
    cy.wait('@dvla');
    cy.contains('This vehicle has a valid tax or MOT, so it does not meet the criteria for an abandoned vehicle report.');
  });

  it('gave a not ok reg plate', function() {
    cy.route('POST', '/report/dvla', 'fixture:bucks_dvla_notok.json').as('dvla');
    cy.get('.js-reporting-page--active').contains('Yes').click();
    cy.get('[name=dvla_reg]').type('B4D');
    cy.nextPageReporting();
    cy.wait('@dvla');
    cy.get('[name=vehicle_registration]').should('have.value', 'B4D');
    cy.get('[name=vehicle_make]').should('have.value', 'Kawasaki');
    cy.get('[name=vehicle_colour]').should('have.value', 'Black');
  });

});
