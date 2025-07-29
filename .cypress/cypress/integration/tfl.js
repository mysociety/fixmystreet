it('allows bus stop clicking outside London', function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('**/mapserver/tfl*busstops*', 'fixture:tfl-bus-stops.xml').as('tfl-bus-stops');
    cy.route('**/mapserver/tfl*RedRoutes*', 'fixture:tfl-tlrn.xml').as('tfl-tlrn');

    // Click on a bus stop outside London...
    cy.visit('http://tfl.localhost:3001/report/new?latitude=51.345714&longitude=-0.227959');
    cy.wait('@report-ajax');
    cy.contains('Transport for London');
    cy.pickCategory('Bus Stops and Shelters');
    cy.wait('@tfl-bus-stops');
    cy.get('.js-reporting-page--active .js-reporting-page--next').click();
    cy.get('.js-subcategory label').contains('Incorrect timetable').click();

    // Also check a category not on a red route
    cy.go('back');
    cy.pickCategory('Mobile Crane Operation');
    cy.get('.pre-button-messaging').contains('does not maintain this road').should('be.visible');
});

it('shows TfL roadworks', function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('**/streetmanager*', 'fixture:tfl-roadworks.json').as('roadworks');
    cy.route('**/mapserver/tfl*RedRoutes*', 'fixture:tfl-tlrn.xml').as('tfl-tlrn');
    cy.viewport(480, 800);

    cy.visit('http://tfl.localhost:3001/report/new?latitude=51.482286&longitude=-0.328163');
    cy.wait('@report-ajax');
    cy.get('#mob_ok').click();
    cy.pickCategory('Roadworks');
    cy.wait('@roadworks');
    cy.get('.js-reporting-page--active .js-reporting-page--next').click();
    cy.contains('You can pick a roadworks from the map').should('be.visible');
    cy.get('.mobile-map-banner').should('be.visible');
    cy.get('#mob_ok').click();
    cy.contains('Major works, with road closure').should('be.visible');
});

it('does not show TfL categories outside London on .com', function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.visit('http://fixmystreet.localhost:3001/');
    cy.visit('http://fixmystreet.localhost:3001/report/new?latitude=51.345714&longitude=-0.227959');
    cy.contains('We do not yet have details').should('be.visible');
});

it('shows TfL categories inside London on .com', function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');

    cy.visit('http://fixmystreet.localhost:3001/');
    cy.get('[name=pc]').type('TW7 5JN');
    cy.get('[name=pc]').parents('form').submit();
    cy.get('#map_box').click(322, 307);
    cy.wait('@report-ajax');
    cy.pickCategory('Bus Stops and Shelters');
    cy.pickCategory('Potholes');
});

it('shows A13 DBFO message', function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('**/mapserver/tfl*RedRoutes*', 'fixture:tfl-tlrn.xml').as('tfl-tlrn');
    cy.route('**/mapserver/tfl*A13TLRN_DBFO*', 'fixture:tfl-a13-dbfo-tlrn.xml').as('tfl-a13-dbfo-tlrn');
    cy.viewport(480, 800);
    cy.visit('http://tfl.localhost:3001/report/new?longitude=-0.011937&latitude=51.511258');
    cy.wait('@report-ajax');
    cy.get('#mob_ok').click();
    cy.pickCategory('Other (TfL)');
    cy.get('.js-reporting-page--active .js-reporting-page--next').click();
    cy.contains('This issue is within the A13 DBFO').should('be.visible');
    cy.visit('http://tfl.localhost:3001/report/new?longitude=-0.013074&latitude=51.512139');
    cy.wait('@report-ajax');
    cy.get('#mob_ok').click();
    cy.pickCategory('Other (TfL)');
    cy.get('.js-reporting-page--active .js-reporting-page--next').click();
    cy.contains('This issue is within the A13 DBFO').should('be.hidden');
});
