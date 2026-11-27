describe('Reporting from the area map', function() {
    it('links to the map centre only when zoomed in far enough', function() {
        cy.visit('/reports/Borsetshire');
        cy.window().its('fixmystreet.map.baseLayer').should('exist');
        cy.window().then(function(win) {
            var map = win.fixmystreet.map;
            // Two adjacent British National Grid resolutions, with local zoom levels 0 and 1.
            var layer = new win.OpenLayers.Layer('Test map', {
                isBaseLayer: true,
                projection: map.getProjectionObject(),
                units: 'm',
                resolutions: [28, 14]
            });
            map.addLayer(layer);
            map.setBaseLayer(layer);
            map.zoomTo(0, null, false);
        });
        cy.get('.report-a-problem-btn').first().should('have.attr', 'href', '/');

        cy.window().then(function(win) {
            var map = win.fixmystreet.map;
            map.zoomTo(1, null, false);
            var center = map.getCenterWGS84();
            var href = '/report/new?longitude=' + center.lon.toFixed(6) + '&latitude=' + center.lat.toFixed(6);
            cy.get('.report-a-problem-btn').first().should('have.text', 'Report a problem here')
                .and('have.attr', 'href', href);
        });

        cy.window().then(function(win) { win.fixmystreet.map.zoomTo(0, null, false); });
        cy.get('.report-a-problem-btn').first().should('have.attr', 'href', '/');
    });
});
