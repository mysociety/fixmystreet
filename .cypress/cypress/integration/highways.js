describe('National Highways tests', function() {
    it('report as defaults to body', function() {
        cy.server();
        cy.route('**/mapserver/highways*', 'fixture:highways.xml').as('highways-tilma');
        cy.route('**/report/new/ajax*', 'fixture:highways-ajax.json').as('report-ajax');
        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.url().should('include', '/around');
        cy.get('#map_box').click(272, 249);
        cy.wait('@report-ajax');
        cy.wait('@highways-tilma');

        cy.get('#highways').should('contain', 'M6');
        cy.get('#js-councils_text').should('contain', 'National Highways');
        cy.get('#single_body_only').should('have.value', 'National Highways');
        cy.nextPageReporting();
        cy.pickCategory('Litter');
        cy.nextPageReporting();
        cy.get('#subcategory_Litter').should('be.visible');
        cy.go('back');
        cy.go('back');

        cy.get('#js-not-highways').click();
        cy.get('#js-councils_text').should('contain', 'Borsetshire');
        cy.get('#single_body_only').should('have.value', '');
        cy.nextPageReporting();
        cy.get('#form_category_fieldset').should('be.visible');
        cy.get('#form_category_fieldset input[value="Litter"]').should('not.be.visible');
        cy.go('back');

        cy.get('#js-highways').click({ force: true });
        cy.get('#js-councils_text').should('contain', 'National Highways');
        cy.get('#single_body_only').should('have.value', 'National Highways');
        cy.nextPageReporting();
        cy.pickCategory('Potholes');
    });
    it('report as defaults to Transport Scotland', function() {
        cy.server();
        cy.route('**/mapserver/highways*', 'fixture:highways-scotland.xml').as('highways-tilma');
        cy.route('**/report/new/ajax*', 'fixture:highways-scotland-ajax.json').as('report-ajax');

        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.url().should('include', '/around');
        cy.get('#map_box').click(272, 249);
        cy.wait('@report-ajax');
        cy.wait('@highways-tilma');

        cy.get('#highways').should('contain', 'A909');
        cy.get('#js-councils_text').should('contain', 'Traffic Scotland');
        cy.get('#single_body_only').should('have.value', 'Traffic Scotland');
        cy.nextPageReporting();
        cy.pickCategory('Litter');
        cy.nextPageReporting();
        cy.get('#subcategory_Litter').should('be.visible');
        cy.go('back');
        cy.go('back');

        cy.get('#js-not-highways').click();
        cy.get('#js-councils_text').should('contain', 'Borsetshire');
        cy.get('#single_body_only').should('have.value', '');
        cy.nextPageReporting();
        cy.get('#form_category_fieldset').should('be.visible');
        cy.get('#form_category_fieldset input[value="Litter"]').should('not.be.visible');
        cy.go('back');

        cy.get('#js-highways').click({ force: true });
        cy.get('#js-councils_text').should('contain', 'Traffic Scotland');
        cy.get('#single_body_only').should('have.value', 'Traffic Scotland');
        cy.nextPageReporting();
        cy.pickCategory('Potholes');
    });
    it('clicking somewhere not on a Traffic Scotland road when initially centred on one still shows the report form', function() {
        // The always-visible road detection layer uses the page lat/lon on
        // initial load to check if the location is on a managed road (via one_time_select).
        // If it is, the highways question page is inserted before all other reporting pages
        // and those pages are deactivated. If the user then clicks somewhere not on the road,
        // not_found removes the highways page — but the other pages are still inactive, so
        // the sidebar is blank and reporting cannot continue.
        cy.server();
        cy.route('**/mapserver/highways*', 'fixture:highways-scotland-dumfries.xml').as('highways-tilma');
        cy.route('**/report/new/ajax*', 'fixture:highways-scotland-ajax.json').as('report-ajax');

        // Visit at coordinates centred on a Traffic Scotland road (Dumfries High Street).
        // The WFS layer fires one_time_select on loadend using the page lat/lon and finds
        // the road, inserting the highways question into the DOM before any user interaction.
        cy.visit('/around?lat=55.15059&lon=-2.99833');
        cy.wait('@highways-tilma');
        cy.get('.js-reporting-page--highways').should('exist');

        // Click somewhere that is not on the TS road — getNearest finds nothing at the
        // new pin location and not_found fires, removing the highways page
        cy.get('#map_box').click(450, 350);
        cy.wait('@report-ajax');
        cy.wait('@highways-tilma');

        // There should still be an active reporting page (not a blank sidebar)
        cy.get('.js-reporting-page--active').should('exist');
    });
});
