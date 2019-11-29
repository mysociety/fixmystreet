it('loads the right front page', function() {
    cy.visit('http://northamptonshire.localhost:3001/');
    cy.contains('Northamptonshire');
});

it('prevents clicking unless asset selected', function() {
  cy.server();
  cy.fixture('bus_stops.json');
  cy.fixture('bus_stops_none.json');
  cy.route('**/render-layer/**', 'fixture:bus_stops_none.json').as('empty-bus_stops-layer');
  cy.route('**/16301/10787**', 'fixture:bus_stops.json').as('bus_stops-layer');
  cy.route('/report/new/ajax*').as('report-ajax');
  cy.visit('http://northamptonshire.localhost:3001/');
  cy.get('[name=pc]').type('NN1 1NS');
  cy.get('[name=pc]').parents('form').submit();

  cy.get('#map_box').click();
  cy.wait('@report-ajax');

  cy.get('[id=category_group]').select('Shelter Damaged');

  cy.wait('@bus_stops-layer');
  cy.wait('@empty-bus_stops-layer');
  cy.contains(/Please select a.*bus stop.*from the map/);
  cy.get('#js-councils_text').should('be.hidden');
});

it('selecting an asset allows a report', function() {
  cy.server();
  cy.fixture('bus_stops.json');
  cy.fixture('bus_stops_none.json');
  cy.route('**/render-layer/**', 'fixture:bus_stops_none.json').as('empty-bus_stops-layer');
  cy.route('**/16301/10787**', 'fixture:bus_stops.json').as('bus_stops-layer');
  cy.route('/report/new/ajax*').as('report-ajax');
  cy.visit('http://northamptonshire.localhost:3001/');
  cy.get('[name=pc]').type('NN1 2NS');
  cy.get('[name=pc]').parents('form').submit();

  cy.get('#map_box').click();
  cy.wait('@report-ajax');

  cy.get('[id=category_group]').select('Shelter Damaged');

  cy.wait('@bus_stops-layer');
  cy.wait('@empty-bus_stops-layer');

  cy.get('#js-councils_text').should('be.visible');
});

it('detects multiple assets at same location', function() {
  cy.server();
  cy.fixture('bus_stops.json');
  cy.fixture('bus_stops_none.json');
  cy.route('**/render-layer/**', 'fixture:bus_stops_none.json').as('empty-bus_stops-layer');
  cy.route('**/16301/10787**', 'fixture:bus_stops.json').as('bus_stops-layer');
  cy.route('**/16301/10788**', 'fixture:bus_stops.json').as('bus_stops-layer2');
  cy.route('/report/new/ajax*').as('report-ajax');
  cy.visit('http://northamptonshire.localhost:3001/');
  cy.get('[name=pc]').type('NN1 2NS');
  cy.get('[name=pc]').parents('form').submit();

  cy.get('#map_box').click();
  cy.wait('@report-ajax');

  cy.get('[id=category_group]').select('Shelter Damaged');

  cy.wait('@bus_stops-layer');
  cy.wait('@bus_stops-layer2');
  cy.wait('@empty-bus_stops-layer');

  cy.contains('more than one bus stop at this location');
});

it('shows the emergency message', function() {
  cy.server();
  cy.route('/report/new/ajax*').as('report-ajax');
  cy.visit('http://northamptonshire.localhost:3001/');
  cy.get('[name=pc]').type('NN1 2NS');
  cy.get('[name=pc]').parents('form').submit();
  cy.get('#map_box').click();
  cy.wait('@report-ajax');
  cy.get('[id=category_group]').select('Very Urgent');
  cy.contains('Please call us instead, it is very urgent.');
  cy.get('#form_title').should('not.be.visible');
});
