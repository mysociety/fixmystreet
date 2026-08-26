describe('Canal & River Trust asset messaging tests', function() {
    before(function() {
        // Make sure desktop
        cy.viewport(1500, 800);
        cy.intercept('POST', '**/mapserver/crt', {fixture: 'canals-for-asset-messaging.xml'}).as('crt-tilma');
        cy.intercept('**/Canal_And_River_Trust_Bridges_View/**', {fixture: 'canal-bridges.json'}).as('crt-bridges');
        cy.intercept('**/report/new/ajax*').as('report-ajax');

        cy.visit('http://canalrivertrust.localhost:3001/report/new?longitude=-0.099152&latitude=51.532974'); // Islington
    });
    it('Select bridge category', function() {
        cy.pickCategory('Bridges');

        // Must select a bridge
        must_select_bridge();

        // Selecting asset should show bridge name
        cy.get('#map_box').click(350, 360);
        cy.get('.js-not-an-asset').should('not.exist');
        cy.get('.js-floating-button-message').invoke('text').should('match', /You have selected bridge Bridge 38/);
        cy.get('.js-reporting-page--next').should('not.be.disabled');

        // Moving pin away from bridge should disable form again
        cy.get('#map_box').click(370, 380);
        must_select_bridge();
    });
});

function must_select_bridge() {
    cy.get('.js-not-an-asset').should('be.visible');
    cy.get('.js-not-an-asset').invoke('text').should('match', /Please select a bridge/);
    cy.get('.js-reporting-page--next').should('be.disabled');
}
