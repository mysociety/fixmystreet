describe('buckinghamshire cobrand', function() {

  beforeEach(function() {
    cy.server();
    cy.fixture('roads.xml');
    cy.route('**mapserver/bucks*Whole_Street*', 'fixture:roads.xml').as('roads-layer');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('/around/nearby*').as('around-ajax');
    cy.visit('http://buckinghamshire.localhost:3001/');
    cy.contains('Buckinghamshire');
    cy.get('[name=pc]').type('SL9 0NX');
    cy.get('[name=pc]').parents('form').submit();
  });

  it('sets the site_code correctly', function() {
    cy.get('.olMapViewport #fms_pan_zoom_zoomin').click();
    cy.wait('@roads-layer');
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.get('select:eq(4)').select('Parks');
    cy.get('[name=site_code]').should('have.value', '7300268');
  });

  it('uses the label "Full name" for the name field', function() {
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.get('select:eq(4)').select('Flytipping');
    cy.wait('@around-ajax');

    cy.get('[name=title]').type('Title');
    cy.get('[name=detail]').type('Detail');
    cy.get('.js-new-report-user-show').click();
    cy.get('label[for=form_name]').should('contain', 'Full name');
  });

});
