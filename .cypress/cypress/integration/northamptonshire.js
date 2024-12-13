it('loads the right front page', function() {
    cy.visit('http://northamptonshire.localhost:3001/');
    cy.contains('Northamptonshire');
});

it('prevents clicking unless asset selected, desktop flow', function() {
  cy.server();
  cy.route('POST', '**mapserver/northamptonshire*', 'fixture:bus_stops.xml').as('bus_stops-layer');
  cy.route('/report/new/ajax*').as('report-ajax');
  cy.visit('http://northamptonshire.localhost:3001/');
  cy.get('[name=pc]').type('NN1 1NS');
  cy.get('[name=pc]').parents('form').submit();

  cy.get('#map_box').click();
  cy.wait('@report-ajax');

  cy.pickCategory('Shelter Damaged');

  cy.wait('@bus_stops-layer');
  cy.get('.pre-button-messaging').contains(/Please select a.*bus stop.*from the map/).should('be.visible');
  cy.get('.js-reporting-page--next:visible').should('be.disabled');
});

it('prevents clicking unless asset selected, mobile flow', function() {
  cy.server();
  cy.route('POST', '**mapserver/northamptonshire*', 'fixture:bus_stops.xml').as('bus_stops-layer');
  cy.route('/report/new/ajax*').as('report-ajax');
  cy.viewport(480, 800);
  cy.visit('http://northamptonshire.localhost:3001/');
  cy.get('[name=pc]').type('NN1 1NS');
  cy.get('[name=pc]').parents('form').submit();

  cy.get('.map-mobile-report-button').click();
  cy.wait('@report-ajax');
  cy.get('#mob_ok').click();

  cy.pickCategory('Shelter Damaged');

  cy.wait('@bus_stops-layer');
  cy.contains(/Please select a.*bus stop.*from the map/).should('not.be.visible');
  cy.nextPageReporting();
  cy.get('.mobile-map-banner').should('be.visible');
  cy.contains(/Please select a.*bus stop.*from the map/).should('be.visible');
  cy.get('#mob_ok').should('not.be.visible');
});

it('selecting an asset allows a report, mobile flow', function() {
  cy.server();
  cy.route('POST', '**mapserver/northamptonshire*', 'fixture:bus_stops.xml').as('bus_stops-layer');
  cy.route('/report/new/ajax*').as('report-ajax');
  cy.viewport(480, 800);
  cy.visit('http://northamptonshire.localhost:3001/');
  cy.get('[name=pc]').type('NN1 2NS');
  cy.get('[name=pc]').parents('form').submit();

  cy.get('.olMapViewport')
    .trigger('mousedown', { which: 1, clientX: 160, clientY: 284 })
    .trigger('mousemove', { which: 1, clientX: 160, clientY: 337 })
    .trigger('mouseup', { which: 1, clientX: 160, clientY: 337 });
  cy.get('.map-mobile-report-button').click();

  cy.wait('@report-ajax');
  cy.get('#mob_ok').click();

  cy.pickCategory('Shelter Damaged');

  cy.wait('@bus_stops-layer');
  cy.contains(/Please select a.*bus stop.*from the map/).should('not.be.visible');
  cy.nextPageReporting();
  cy.get('.mobile-map-banner').should('be.visible');
  cy.get('#mob_ok').click();
  cy.nextPageReporting(); // No photo
  cy.get('#js-councils_text').should('be.visible');
});

it('selecting an asset allows a report, desktop flow', function() {
  cy.server();
  cy.route('POST', '**mapserver/northamptonshire*', 'fixture:bus_stops.xml').as('bus_stops-layer');
  cy.route('/report/new/ajax*').as('report-ajax');
  cy.visit('http://northamptonshire.localhost:3001/');
  cy.get('[name=pc]').type('NN1 2NS');
  cy.get('[name=pc]').parents('form').submit();

  cy.get('#map_box').click(268, 225);
  cy.wait('@report-ajax');

  cy.pickCategory('Shelter Damaged');

  cy.wait('@bus_stops-layer');

  cy.nextPageReporting();
  cy.nextPageReporting(); // No photo
  cy.get('#js-councils_text').should('be.visible');
});

it('detects multiple assets at same location', function() {
  cy.server();
  cy.route('POST', '**mapserver/northamptonshire*', 'fixture:bus_stops_multiple.xml').as('bus_stops_multiple-layer');
  cy.route('/report/new/ajax*').as('report-ajax');
  cy.visit('http://northamptonshire.localhost:3001/');
  cy.get('[name=pc]').type('NN1 2NS');
  cy.get('[name=pc]').parents('form').submit();

  cy.get('#map_box').click(268, 225);
  cy.wait('@report-ajax');

  cy.pickCategory('Shelter Damaged');

  cy.wait('@bus_stops_multiple-layer');
  cy.nextPageReporting();

  cy.contains('more than one bus stop at this location').should('be.visible');
});

it('shows the emergency message', function() {
  cy.server();
  cy.route('/report/new/ajax*').as('report-ajax');
  cy.visit('http://northamptonshire.localhost:3001/');
  cy.get('[name=pc]').type('NN1 2NS');
  cy.get('[name=pc]').parents('form').submit();
  cy.get('#map_box').click();
  cy.wait('@report-ajax');
  cy.pickCategory('Very Urgent');
  cy.contains('Please call us instead, it is very urgent.').should('be.visible');
  cy.get('#form_title').should('not.be.visible');
});
