describe('Canal & River Trust asset messaging tests', function() {
    before(function() {
        cy.intercept('POST', '**/mapserver/crt', {fixture: 'canals-for-asset-messaging.xml'}).as('crt-tilma');
        cy.intercept('**/Canal_And_River_Trust_Bridges_View/**', {fixture: 'canal-bridges.json'}).as('crt-bridges');
        cy.intercept('**/Web_CSF_Facilities/**', {fixture: 'canal-elsan.json'}).as('crt-elsan');
        cy.intercept('**/report/new/ajax*').as('report-ajax');

        // Make sure desktop
        cy.viewport(1500, 800);
        cy.visit('http://canalrivertrust.localhost:3001/report/new?longitude=-0.099152&latitude=51.532974'); // Islington
    });
    it('Select categories', function() {
        // Bridges
        cy.pickCategory('Bridges');
        must_select_asset('bridge');

        // Selecting asset should show bridge name
        cy.get('circle:visible').first().click();
        cy.get('.js-not-an-asset').should('not.exist');
        cy.get('.js-floating-button-message').invoke('text').should('match', /You have selected bridge Bridge 38/);
        cy.get('.js-reporting-page--next').should('not.be.disabled');

        // Moving pin away from bridge should disable form again
        cy.get('#map_box').click(370, 380);
        must_select_asset('bridge');

        // Elsan
        cy.pickCategory('Elsan');
        must_select_asset('elsan');

        // Selecting asset should enable form and hide all messaging
        cy.get('circle:visible').first().click();
        cy.get('.js-not-an-asset').should('not.exist');
        cy.get('.js-floating-button-message').should('not.exist');
        cy.get('.js-reporting-page--next').should('not.be.disabled');

        // Moving pin away from elsan should disable form again
        cy.get('#map_box').click(370, 380);
        must_select_asset('elsan');
    });
});

function must_select_asset(asset) {
    cy.get('.js-not-an-asset').should('be.visible');
    cy.get('.js-not-an-asset').invoke('text').should(
        'match',
        new RegExp('Please select a ' + asset)
    );
    cy.get('.js-reporting-page--next').should('be.disabled');
}
