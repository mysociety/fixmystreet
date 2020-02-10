it('allows bus stop clicking outside London', function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.fixture('tfl-bus-stops.xml');
    cy.route('**/mapserver/tfl*busstops*', 'fixture:tfl-bus-stops.xml').as('tfl-bus-stops');
    cy.route('**/mapserver/tfl*RedRoutes*', 'fixture:tfl-tlrn.xml').as('tfl-tlrn');

    // Click on a bus stop outside London...
    cy.visit('http://tfl.localhost:3001/report/new?latitude=51.345714&longitude=-0.227959');
    cy.wait('@report-ajax');
    cy.contains('Transport for London');
    cy.get('[id=category_group]').select('Bus Stops and Shelters');
    cy.wait('@tfl-bus-stops');
    cy.get('.js-subcategory').select('Incorrect timetable');

    // Also check a category not on a red route
    cy.get('[id=category_group]').select('Mobile Crane Operation');
    cy.contains('does not maintain this road');
});

it('does not show TfL categories outside London on .com', function() {
    cy.visit('http://fixmystreet.localhost:3001/report/new?latitude=51.345714&longitude=-0.227959');
    cy.contains('We do not yet have details');
});

it('shows TfL categories inside London on .com', function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');

    cy.visit('http://fixmystreet.localhost:3001/');
    cy.get('[name=pc]').type('TW7 5JN');
    cy.get('[name=pc]').parents('form').submit();
    cy.get('#map_box').click(290, 307);
    cy.wait('@report-ajax');
    cy.get('[id=category_group]').select('Bus Stops and Shelters');
    cy.get('[id=category_group]').select('Potholes');
});
