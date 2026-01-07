describe('Photo-first reporting with GPS', function() {
    beforeEach(function() {
        cy.server();
        cy.route('POST', '/photo/upload*').as('photo-upload');
        cy.route('/report/new/ajax*').as('report-ajax');
    });

    it('uploads photo with GPS and redirects to /report/new with location', function() {
        cy.visit('/');

        var dropEvent = { dataTransfer: { files: [] } };
        cy.fixture('../fixtures/photo_with_gps.jpeg').then(function(picture) {
            return Cypress.Blob.base64StringToBlob(picture, 'image/jpeg').then(function(blob) {
                dropEvent.dataTransfer.files.push(blob);
            });
        });

        cy.get('#photoFormPhoto').trigger('drop', dropEvent);
        cy.wait('@photo-upload');

        // Should redirect to /report/new with lat/lon/photo_id
        cy.url().should('include', '/report/new');
        cy.url().should('include', 'lat=');
        cy.url().should('include', 'lon=');
        cy.url().should('include', 'photo_id=');
    });

    it('shows photo confirmation page on desktop', function() {
        cy.viewport(1200, 800);
        cy.visit('/');

        var dropEvent = { dataTransfer: { files: [] } };
        cy.fixture('../fixtures/photo_with_gps.jpeg').then(function(picture) {
            return Cypress.Blob.base64StringToBlob(picture, 'image/jpeg').then(function(blob) {
                dropEvent.dataTransfer.files.push(blob);
            });
        });

        cy.get('#photoFormPhoto').trigger('drop', dropEvent);
        cy.wait('@photo-upload');

        cy.get('[data-page-name="photo-confirm"]').should('be.visible');
        cy.contains('Photo uploaded successfully').should('be.visible');
        cy.get('.photo-preview img').should('be.visible');

        cy.get('[data-page-name="photo-confirm"] .js-reporting-page--next').click();

        // Should move to category selection
        cy.get('[data-page-name="category"]').should('be.visible');
    });

    it('skips confirmation page on mobile viewport', function() {
        cy.viewport(375, 667);
        cy.visit('/');

        var dropEvent = { dataTransfer: { files: [] } };
        cy.fixture('../fixtures/photo_with_gps.jpeg').then(function(picture) {
            return Cypress.Blob.base64StringToBlob(picture, 'image/jpeg').then(function(blob) {
                dropEvent.dataTransfer.files.push(blob);
            });
        });

        cy.get('#photoFormPhoto').trigger('drop', dropEvent);
        cy.wait('@photo-upload');

        // Confirmation page should NOT be visible on mobile
        cy.get('[data-page-name="photo-confirm"]').should('not.be.visible');

        // Category selection should be visible
        cy.get('[data-page-name="category"]').should('be.visible');
    });

    it('completes full report creation with GPS photo', function() {
        cy.viewport(1200, 800);
        cy.visit('/');

        var dropEvent = { dataTransfer: { files: [] } };
        cy.fixture('../fixtures/photo_with_gps.jpeg').then(function(picture) {
            return Cypress.Blob.base64StringToBlob(picture, 'image/jpeg').then(function(blob) {
                dropEvent.dataTransfer.files.push(blob);
            });
        });

        cy.get('#photoFormPhoto').trigger('drop', dropEvent);
        cy.wait('@photo-upload');

        cy.wait('@report-ajax');

        cy.get('[data-page-name="photo-confirm"] .js-reporting-page--next').click();

        cy.pickCategory('Flyposting');
        cy.nextPageReporting();

        // Skip photo page (already have photo from upload)
        cy.nextPageReporting();

        cy.get('[name=title]').type('Test from GPS photo');
        cy.get('[name=detail]').type('Detail from photo-first GPS upload');
        cy.nextPageReporting();

        cy.get('.js-new-report-show-sign-in').should('be.visible').click();
        cy.get('#form_username_sign_in').type('cs@example.org');
        cy.get('[name=password_sign_in]').type('password');
        cy.get('[name=password_sign_in]').parents('form').submit();

        cy.get('#map_sidebar').should('contain', 'check and confirm your details');
        cy.get('#map_sidebar').parents('form').submit();
        cy.contains('Thank you for reporting this issue');
    });
});
