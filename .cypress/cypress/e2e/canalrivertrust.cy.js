describe('Canal & River Trust asset messaging tests', function() {
    beforeEach(function() {
        cy.intercept('POST', '**/mapserver/crt', {fixture: 'canals-islington.xml'}).as('crt-tilma');
        cy.intercept('GET', '**/mapserver/crt*Bridges*', {fixture: 'canal-bridges.xml'}).as('crt-bridges');
        cy.intercept('GET', '**/mapserver/crt*Facilities*', {fixture: 'canal-elsan.xml'}).as('crt-elsan');
        cy.intercept('GET', '**/mapserver/crt*Tunnels*', {fixture: 'canal-tunnels.xml'}).as('crt-tunnels');
        cy.intercept('GET', '**/mapserver/crt*Tunnel_Portals*', {fixture: 'canal-tunnel-portals.xml'}).as('crt-tunnel-portals');
        cy.intercept('**/report/new/ajax*').as('report-ajax');
        cy.intercept('/around/nearby*').as('nearby-ajax');

        // Make sure desktop
        cy.viewport(1500, 800);
        cy.visit('http://canalrivertrust.localhost:3001/report/new?longitude=-0.099152&latitude=51.532974'); // Islington
        cy.wait('@crt-tilma');
        cy.wait('@report-ajax');
    });
    it('does not allow reporting on non-canal', function() {
        cy.get('.pre-button-messaging').contains('The selected location is not maintained by us.').should('be.visible');
        cy.get('.js-reporting-page--next').should('be.disabled');
    });
    it('select categories', function() {
        // Bridges
        cy.pickCategory('Bridges');
        cy.wait('@crt-tilma');
        cy.wait('@nearby-ajax');
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
        cy.get('#map_box').click(430,385);
        cy.wait('@crt-tilma');
        cy.wait('@report-ajax');
        cy.wait('@crt-bridges');
        cy.get('.js-not-an-asset').should('be.visible');

        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a bridge/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');
        // Elsan
        cy.pickCategory('Elsan');
        cy.wait('@crt-elsan');
        cy.wait('@nearby-ajax');
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
        cy.get('#map_box').click(430,355);
        cy.wait('@crt-tilma');
        cy.wait('@report-ajax');
        cy.wait('@crt-elsan');
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a elsan/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');

        // Tunnel
        cy.pickCategory('Tunnel');
        cy.wait('@crt-tunnels');
        cy.wait('@crt-tunnel-portals');
        cy.wait('@nearby-ajax');
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a tunnel or a tunnel portal/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');

        // Make sure messaging disappears if another category (but not asset) selected
        cy.pickCategory('Elsan');
        cy.wait('@nearby-ajax');
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a elsan/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');
        cy.get('.js-not-an-asset').invoke('text').should('not.match', /tunnel/);

        cy.pickCategory('Tunnel');
        cy.wait('@nearby-ajax');
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /Please select a tunnel or a tunnel portal/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');

        // Make sure messaging disappears if another category+asset selected
        cy.pickCategory('Elsan');
        cy.wait('@nearby-ajax');
        cy.get('circle:visible').first().click();
        cy.get('.js-not-an-asset').should('not.exist');
        cy.get('.js-reporting-page--next').should('not.be.disabled');

        cy.pickCategory('Tunnel');
        cy.wait('@nearby-ajax');
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
        cy.get('#map_box').click(75,230);
        cy.wait('@crt-tilma');
        cy.wait('@report-ajax');
        cy.wait('@crt-tunnels');
        cy.wait('@crt-tunnel-portals');
        cy.get('.js-floating-button-message').invoke('text').should('match', /You have selected tunnel Islington Tunnel/);

        // Boating etiquette - no messaging should show
        cy.pickCategory('Boating etiquette');
        cy.wait('@nearby-ajax');
        cy.get('.js-not-an-asset').should('not.exist');
        cy.get('.js-floating-button-message').should('not.exist');
        cy.get('.js-reporting-page--next').should('not.be.disabled');
    });
    it('does not allow reporting on assets the Trust does not own', function() {
        cy.intercept('GET', '**/mapserver/crt*Bridges*', {fixture: 'canal-bridges-not-trust-owned.xml'}).as('crt-bridges');
        cy.pickCategory('Bridges');
        cy.wait('@nearby-ajax');
        cy.wait('@crt-bridges');
        cy.get('.js-reporting-page--next').should('be.disabled');

        cy.get('circle:visible').first().click();
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /selected a bridge that isn’t maintained by the Canal & River Trust/
        );
        cy.get('.js-not-an-asset').invoke('text').should('not.match', /You have selected/);
        cy.get('.js-reporting-page--next').should('be.disabled');
    });
    it('does not allow reporting on tunnels the Trust does not own', function() {
        cy.intercept('GET', '**/mapserver/crt*Tunnels*', {fixture: 'canal-tunnels-not-trust-owned.xml'}).as('crt-tunnels');
        cy.pickCategory('Tunnel');
        cy.wait('@nearby-ajax');
        cy.wait('@crt-tunnels');

        cy.get('#map_box').click(20,289);
        cy.wait('@crt-tilma');
        cy.wait('@report-ajax');
        cy.wait('@crt-tunnels');
        cy.get('.js-not-an-asset').should('be.visible');
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /selected a tunnel that isn’t maintained by the Canal & River Trust/
        );
        cy.get('.js-not-an-asset').invoke('text').should('not.match', /You have selected/);
        cy.get('.js-reporting-page--next').should('be.disabled');
    });
    it('allows reporting on a tunnel after selecting a portal the Trust does not own', function() {
        cy.intercept('GET', '**/mapserver/crt*Tunnel_Portals*', {fixture: 'canal-tunnel-portals-not-trust-owned.xml'}).as('crt-tunnel-portals');
        cy.pickCategory('Tunnel');
        cy.wait('@nearby-ajax');
        cy.wait('@crt-tunnel-portals');

        cy.get('circle:visible').first().click();
        cy.get('.js-not-an-asset').invoke('text').should(
            'match', /selected a portal that isn’t maintained by the Canal & River Trust/
        );
        cy.get('.js-reporting-page--next').should('be.disabled');

        cy.get('#map_box').click(20,289);
        cy.wait('@crt-tilma');
        cy.wait('@report-ajax');
        cy.wait('@crt-tunnels');
        cy.get('.js-floating-button-message').invoke('text').should('match', /You have selected tunnel Islington Tunnel/);
        cy.get('.js-not-an-asset').should('not.exist');
        cy.get('.js-reporting-page--next').should('not.be.disabled');
    });
});
