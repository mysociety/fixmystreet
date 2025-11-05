it("zooms in when asset layer shown from around page", function() {
    cy.server();
    cy.route('/report/*').as('show-report');
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.route('/proxy/camden/wfs*', 'fixture:camden-trees.xml').as('trees-layer');

    cy.visit('http://camden.localhost:3001/_test/setup/camden-report-ours');
    cy.visit('http://camden.localhost:3001/report/1');
    cy.contains('Problems nearby').click();
    cy.get('[href$="/report/1"]').last().click();
    cy.wait('@show-report');
    cy.contains('Report another problem here').click();
    cy.wait('@report-ajax');
    cy.pickCategory('Trees');
    cy.wait('@trees-layer');
    cy.contains('You can pick a');

    cy.visit('http://camden.localhost:3001/_test/teardown/camden-report-ours');
});
