describe('private categories', function() {

  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
  });

  it('shows the correct UI text for private and public categories on cobrand', function() {
    cy.visit('http://hounslow.localhost:3001/');
    cy.contains('Hounslow Highways');
    cy.get('[name=pc]').type('TW7 5JN');
    cy.get('[name=pc]').parents('form').submit();
    cy.get('.olMapViewport #fms_pan_zoom_zoomin').click();
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.get('select:eq(4)').select('Potholes');
    cy.get("#js-councils_text").contains('sent to Hounslow Highways and also published online');
    cy.get('select:eq(4)').select('Other');
    cy.get("#js-councils_text").contains('sent to Hounslow Highways but not published online');
  });

  it('shows the correct UI text for private and public categories on FMS.com', function() {
    cy.visit('http://fixmystreet.localhost:3001/');
    cy.get('[name=pc]').type('TW7 5JN');
    cy.get('[name=pc]').parents('form').submit();
    cy.get('.olMapViewport #fms_pan_zoom_zoomin').click();
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.get('select:eq(4)').select('Potholes');
    cy.contains('sent to Hounslow Borough Council and also published online');
    cy.get('select:eq(4)').select('Other');
    cy.contains('sent to Hounslow Borough Council but not published online');
  });

});
