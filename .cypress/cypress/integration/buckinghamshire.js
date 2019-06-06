describe('flytipping', function() {

  beforeEach(function() {
    cy.server();
    cy.fixture('roads.xml');
    cy.route('**mapserver/bucks*Whole_Street*', 'fixture:roads.xml').as('roads-layer');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.visit('http://buckinghamshire.localhost:3001/');
    cy.contains('Buckinghamshire');
    cy.get('[name=pc]').type('SL9 0NX');
    cy.get('[name=pc]').parents('form').submit();
  });

  it('handles flytipping on a road correctly', function() {
    cy.get('.olMapViewport #fms_pan_zoom_zoomin').click();
    cy.wait('@roads-layer');
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.get('select:eq(4)').select('Flytipping');
    cy.get('#form_road-placement').select('off-road');
    cy.contains('sent to Chiltern District Council and also');
    cy.get('#form_road-placement').select('road');
    cy.contains('sent to Buckinghamshire County Council and also');
  });

  it('handles flytipping off a road correctly', function() {
    cy.get('#map_box').click(200, 307);
    cy.wait('@report-ajax');
    cy.get('select:eq(4)').select('Flytipping');
    cy.contains('sent to Chiltern District Council and also');
  });

});
