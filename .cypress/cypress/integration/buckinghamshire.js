describe('buckinghamshire cobrand', function() {

  beforeEach(function() {
    cy.server();
    cy.route('**mapserver/bucks*Whole_Street*', 'fixture:roads.xml').as('roads-layer');
    cy.route('**mapserver/bucks*WinterRoutes*', 'fixture:roads.xml').as('winter-routes');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('/around\?ajax*').as('update-results');
    cy.route('/around/nearby*').as('around-ajax');
    cy.visit('http://buckinghamshire.localhost:3001/');
    cy.contains('Buckinghamshire');
    cy.get('[name=pc]').type('SL9 0NX');
    cy.get('[name=pc]').parents('form').submit();
    cy.wait('@update-results');
  });

  it('sets the site_code correctly', function() {
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Roads & Pavements');
    cy.wait('@roads-layer');
    cy.nextPageReporting();
    cy.get('#subcategory_RoadsPavements label').contains('Parks').click();
    cy.get('[name=site_code]').should('have.value', '7300268');
    cy.nextPageReporting();
    cy.contains('Photo').should('be.visible');
  });

  it('uses the label "Full name" for the name field', function() {
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Flytipping');
    cy.wait('@around-ajax');

    cy.nextPageReporting();
    cy.get('#form_road-placement').select('off-road');
    cy.nextPageReporting();
    cy.nextPageReporting(); // No photo
    cy.get('[name=title]').type('Title');
    cy.get('[name=detail]').type('Detail');
    cy.nextPageReporting();
    cy.get('label[for=form_name]').should('contain', 'Full name');
  });

  it('shows gritting message', function() {
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Roads & Pavements');
    cy.wait('@roads-layer');
    cy.nextPageReporting();
    cy.get('#subcategory_RoadsPavements label').contains('Snow and ice problem/winter salting').click();
    cy.wait('@winter-routes');
    cy.nextPageReporting();
    cy.contains('The road you have selected is on a regular gritting route').should('be.visible');
  });

});

describe('buckinghamshire roads handling', function() {
  it('makes you move the pin if not on a road', function() {
    cy.server();
    cy.route('**mapserver/bucks*Whole_Street*', 'fixture:roads.xml').as('roads-layer');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.viewport(480, 800);
    cy.visit('http://buckinghamshire.localhost:3001/');
    cy.get('[name=pc]').type('SL9 0NX');
    cy.get('[name=pc]').parents('form').submit();

    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.get('#mob_ok').should('be.visible').click();
    cy.pickCategory('Roads & Pavements');
    cy.wait('@roads-layer');
    cy.nextPageReporting();
    cy.get('#subcategory_RoadsPavements label').contains('Parks').click();
    cy.nextPageReporting();
    cy.contains('Please select a road on which to make a report.').should('be.visible');
  });
});
