describe('Photo-first reporting with GPS', function() {
    beforeEach(function() {
        cy.server();
        cy.route('POST', '/photo/upload*').as('photo-upload');
        cy.route('/report/new/ajax*').as('report-ajax');
    });

    describe('Desktop behaviour', function() {
        beforeEach(function() {
            cy.viewport(1200, 800);
            cy.visit('/');
        });

        it('uploads photo with GPS', function() {
            cy.uploadPhoto('photo_with_gps.jpeg', '#photoFormPhoto');

            // Should redirect to /report/new with lat/lon/photo_id
            cy.url().should('include', '/report/new');
            cy.url().should('include', 'lat=');
            cy.url().should('include', 'lon=');
            cy.url().should('include', 'photo_id=');

            cy.get('[data-page-name="photo-confirm"]').should('be.visible');
            cy.contains('Photo uploaded successfully').should('be.visible');
            cy.get('.photo-preview img').should('be.visible');

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
        });

        it('uploads photo without GPS', function() {
            cy.uploadPhoto('photo.jpeg', '#photoFormPhoto');

            cy.url().should('include', '/around');
            cy.url().should('include', 'photo_id=');

            cy.contains('now need to locate your problem').should('be.visible');
            cy.get('.photo-preview img').should('be.visible');

            cy.get('[name=pc]').type(Cypress.env('postcode'));
            cy.get('[name=pc]').parents('form').submit();
            cy.get('#map_box').click(200, 200);
            cy.wait('@report-ajax');
            cy.pickCategory('Flyposting');
            cy.nextPageReporting();

            cy.get('[data-dz-thumbnail]').should('be.visible');
            cy.get('[name="upload_fileid"]').should('have.value', 'd4d1141b8a580f77f988b9bc0f4b1cf97ddc9619.jpeg');
        });
    });

    describe('Mobile behaviour', function() {
        beforeEach(function() {
            cy.viewport(480, 800);
            cy.visit('/');
        });

        it('skips confirmation page on mobile viewport', function() {
            cy.uploadPhoto('photo_with_gps.jpeg', '#photoFormPhoto');
            cy.get('#mob_ok').click();
            cy.get('[data-page-name="photo-confirm"]').should('not.be.visible');
            cy.get('[data-page-name="category"]').should('be.visible');
        });

        it('skips confirmation page on mobile viewport', function() {
            cy.uploadPhoto('photo.jpeg', '#photoFormPhoto');
            cy.url().should('include', '/around');
            cy.url().should('include', 'photo_id=');

            cy.contains('now need to locate your problem').should('be.visible');
            cy.get('.photo-preview img').should('be.visible');

            cy.get('[name=pc]').type('51.499373,-2.610133');
            cy.get('[name=pc]').parents('form').submit();
            cy.wait('@report-ajax');
            cy.get('#mob_ok').click();
            cy.pickCategory('Flyposting');
            cy.nextPageReporting();

            cy.get('[data-dz-thumbnail]').should('be.visible');
            cy.get('[name="upload_fileid"]').should('have.value', 'd4d1141b8a580f77f988b9bc0f4b1cf97ddc9619.jpeg');
            cy.nextPageReporting();
        });
    });
});
