describe('Canal & River Trust asset messaging tests', function() {
    before(function() {
        cy.intercept('POST', '**/mapserver/crt', {fixture: 'canals-for-asset-messaging.xml'}).as('crt-tilma');
        cy.intercept('**/Canal_And_River_Trust_Bridges_View/**', {fixture: 'canal-bridges.json'}).as('crt-bridges');
        cy.intercept('**/Web_CSF_Facilities/**', {fixture: 'canal-elsan.json'}).as('crt-elsan');
        cy.intercept('**/Canal_And_River_Trust_Tunnels_View/**', {fixture: 'canal-tunnels.json'}).as('crt-tunnels');
        cy.intercept('**/Canal_And_River_Trust_Tunnel_Portals_View/**', {fixture: 'canal-tunnel-portals.json'}).as('crt-tunnel-portals');
        cy.intercept('**/report/new/ajax*').as('report-ajax');

        // Make sure desktop
        cy.viewport(1500, 800);
        cy.visit('http://canalrivertrust.localhost:3001/report/new?longitude=-0.099152&latitude=51.532974'); // Islington
        cy.wait('@crt-tilma');
    });
    it('Select categories', function() {
        // Bridges
        cy.pickCategory('Bridges');
        cy.wait('@crt-bridges');
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a bridge/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');

        // Selecting asset should show bridge name
        cy.get('circle:visible').first().click();
        cy.get('.js-not-an-asset').should('not.exist');
        cy.get('.js-floating-button-message').invoke('text').should('match', /You have selected bridge Bridge 38/);
        cy.get('.js-reporting-page--next').should('not.be.disabled');

        // Moving pin away from bridge should disable form again
        cy.get('#map_box').click();
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a bridge/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');

        // Elsan
        cy.pickCategory('Elsan');
        cy.wait('@crt-elsan');
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a elsan/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');

        // Selecting asset should enable form and hide all messaging
        cy.get('circle:visible').first().click();
        cy.get('.js-not-an-asset').should('not.exist');
        cy.get('.js-floating-button-message').should('not.exist');
        cy.get('.js-reporting-page--next').should('not.be.disabled');

        // Moving pin away from elsan should disable form again
        cy.get('#map_box').click();
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a elsan/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');

        // Tunnel
        cy.pickCategory('Tunnel');
        cy.wait('@crt-tunnels');
        cy.wait('@crt-tunnel-portals');
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a tunnel or a tunnel portal/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');

        // Make sure messaging disappears if another category (but not asset) selected
        cy.pickCategory('Elsan');
        // cy.wait('@crt-elsan');
        cy.get('#map_box').click();
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a elsan/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');
        cy.get('.js-not-an-asset').invoke('text').should('not.match', /tunnel/);

        cy.pickCategory('Tunnel');
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a tunnel or a tunnel portal/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');

        // Make sure messaging disappears if another category+asset selected
        cy.pickCategory('Elsan');
        cy.get('circle:visible').first().click();
        cy.get('.js-not-an-asset').should('not.exist');
        cy.get('.js-reporting-page--next').should('not.be.disabled');

        cy.pickCategory('Tunnel');
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a tunnel or a tunnel portal/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');

        // Select a tunnel portal
        cy.get('circle:visible').first().click();
        cy.get('.js-floating-button-message').invoke('text').should('match', /You have selected portal Islington Tunnel East Portal/);
        cy.get('.js-reporting-page--next').should('not.be.disabled');

        // Select a tunnel
        cy.visit('http://canalrivertrust.localhost:3001/report/new?longitude=-0.099152&latitude=51.532974');
        cy.wait('@crt-tilma');
        cy.get('#map_box').click(200,300);
        cy.pickCategory('Tunnel');
        cy.wait('@crt-tunnels');
        cy.wait('@crt-tunnel-portals');
        cy.get('.js-floating-button-message').invoke('text').should('match', /You have selected tunnel Islington Tunnel/);

    });
});
