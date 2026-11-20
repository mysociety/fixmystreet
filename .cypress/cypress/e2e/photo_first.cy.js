describe('Photo-first reporting with GPS', function() {
    beforeEach(function() {
        cy.intercept('POST', '/photo/upload*').as('photo-upload');
        cy.intercept('/report/new/ajax*').as('report-ajax');
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

            cy.get('[name=pc]').type('L2 3SW');
            cy.get('[name=pc]').parents('form').submit();
            cy.get('#map_box').click(200, 200);
            cy.wait('@report-ajax');
            cy.pickCategory('Flyposting');
            cy.nextPageReporting();

            cy.get('[data-dz-thumbnail]').should('be.visible');
            cy.get('[name="upload_fileid"]').should('have.value', 'd4d1141b8a580f77f988b9bc0f4b1cf97ddc9619.jpeg');
        });

        it('uses device location for recently taken photo without GPS', function() {
            cy.window().then(function(win) {
                cy.stub(win.navigator.geolocation, 'getCurrentPosition').callsFake(function(success) {
                    success({ coords: { latitude: 51.499373, longitude: -2.610133 } });
                });
            });
            cy.uploadPhoto('photo.jpeg', '#photoFormPhoto', Date.now());

            cy.url().should('include', '/report/new');
            cy.url().should('include', 'lat=51.49937');
            cy.url().should('include', 'lon=-2.61013');
            cy.url().should('include', 'photo_id=');
            cy.url().should('include', 'photo_first=1');

            cy.get('[data-page-name="photo-confirm"]').should('be.visible');
            cy.get('.photo-preview img').should('be.visible');

            cy.wait('@report-ajax');
            cy.get('[data-page-name="photo-confirm"] .js-reporting-page--next').click();

            cy.pickCategory('Flyposting');
            cy.nextPageReporting();

            cy.get('[data-dz-thumbnail]').should('be.visible');
            cy.get('[name="upload_fileid"]').should('have.value', 'd4d1141b8a580f77f988b9bc0f4b1cf97ddc9619.jpeg');
        });

        it('goes to /around if device geolocation failed', function() {
            cy.window().then(function(win) {
                cy.stub(win.navigator.geolocation, 'getCurrentPosition').callsFake(function(success, error) {
                    error({ code: 1 });
                });
            });
            cy.uploadPhoto('photo.jpeg', '#photoFormPhoto', Date.now());

            cy.url().should('include', '/around');
            cy.url().should('include', 'photo_id=');
            cy.url().should('not.include', 'lat=');
            cy.url().should('not.include', 'lon=');
            cy.contains('now need to locate your problem').should('be.visible');
        });

        it('goes to /around if photo without gps is too old', function() {
            cy.window().then(function(win) {
                cy.stub(win.navigator.geolocation, 'getCurrentPosition');
            });
            cy.uploadPhoto('photo.jpeg', '#photoFormPhoto', Date.now() - 3 * 60 * 1000); // make the photo 3 minutes old

            cy.url().should('include', '/around');
            cy.url().should('include', 'photo_id=');
            cy.url().should('not.include', 'lat=');
            cy.url().should('not.include', 'lon=');
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
