var hosts = [
    'fixmystreet',
    'gloucestershire',
];

describe('Canal and highway cross', function() {
    beforeEach(function() {
        // Make sure desktop
        cy.viewport(1500, 800);
        cy.intercept('**/mapserver/crt*', {fixture: 'canals-gloucestershire-cross-highway.xml'}).as('crt-tilma');
        cy.intercept('**/mapserver/highways*', {fixture: 'highways-gloucestershire-cross-canal.xml'}).as('highways-tilma');
        cy.intercept('**/mapserver/tfl*').as('tfl-tilma');
        cy.intercept('**/report/new/ajax*').as('report-ajax');
    });
    hosts.forEach(function(host){
        describe(host, function() {
            beforeEach(function() {
                cy.visit('http://' + host + '.localhost:3001/report/new?longitude=-2.260300&latitude=51.875422');
                cy.wait('@crt-tilma');
                cy.wait('@highways-tilma');
                cy.wait('@report-ajax');
                if (host === 'fixmystreet')
                    cy.wait('@tfl-tilma');
            });
            it('Select "on canal" option', function() {
                cy.get('#form_category_fieldset').should('not.be.visible');
                cy.nextPageReporting(); // Canal option selected by default

                cy.get('#form_category_fieldset').should('be.visible');

                // Standard hidden
                cy.get('.govuk-radios__item').contains('A pothole in pavement');
                cy.get('.hidden-canals-choice').contains('A pothole in pavement');

                // Canals shown
                cy.get('.govuk-radios__item').contains('Boating etiquette');
                cy.get('.govuk-radios__item').contains('Has canal subcategory');
                cy.get('.hidden-canals-choice').contains('Boating etiquette').should('not.exist');
                cy.get('.hidden-canals-choice').contains('Has canal subcategory').should('not.exist');

                // NH hidden
                cy.get('.govuk-radios__item').contains('Driver on phone');
                cy.get('.hidden-canals-choice').contains('Driver on phone');
                cy.get('.hidden-highways-choice').should('not.exist');

                cy.pickCategory('Has canal subcategory');
                cy.nextPageReporting();

                cy.pickSubcategory('Has canal subcategory', 'Canal');
                cy.nextPageReporting();
                cy.nextPageReporting();

                cy.get('#js-councils_text').contains('These will be sent to Canal & River Trust');
            });
            it('Select "somewhere else" -> "on highway" option', function() {
                cy.get('#form_category_fieldset').should('not.be.visible');
                cy.get('#js-not-canals').click();
                cy.nextPageReporting();

                cy.get('#form_category_fieldset').should('not.be.visible');
                cy.nextPageReporting(); // Highway option selected by default

                cy.get('#form_category_fieldset').should('be.visible');

                // Standard hidden
                cy.get('.govuk-radios__item').contains('A pothole in pavement');
                cy.get('.hidden-canals-choice').contains('A pothole in pavement').should('not.exist');
                cy.get('.hidden-highways-choice').contains('A pothole in pavement');

                // Canals hidden
                // All are marked as hidden-highways-choice.
                // 'Has canal subcategory' is not marked as hidden-canals-choice
                // because it also has a non-canals subcategory.
                cy.get('.govuk-radios__item').contains('Boating etiquette');
                cy.get('.govuk-radios__item').contains('Has canal subcategory');
                cy.get('.hidden-canals-choice').contains('Boating etiquette');
                cy.get('.hidden-canals-choice').contains('Has canal subcategory').should('not.exist');
                cy.get('.hidden-highways-choice').contains('Boating etiquette');
                cy.get('.hidden-highways-choice').contains('Has canal subcategory');

                // NH shown
                cy.get('.govuk-radios__item').contains('Driver on phone');
                cy.get('.hidden-canals-choice').contains('Driver on phone').should('not.exist');
                cy.get('.hidden-highways-choice').contains('Driver on phone').should('not.exist');

                cy.pickCategory('Driver on phone');
                cy.nextPageReporting();
                cy.nextPageReporting();

                cy.get('#js-councils_text').contains('These will be sent to National Highways');
            });
            it('Select "somewhere else" -> "somewhere else" option', function() {
                cy.get('#form_category_fieldset').should('not.be.visible');
                cy.get('#js-not-canals').click();
                cy.nextPageReporting();

                cy.get('#form_category_fieldset').should('not.be.visible');
                cy.get('#js-not-highways').click();
                cy.nextPageReporting();

                // Standard shown. Includes 'Has canal subcategory' because it
                // also has a non-canals subcategory.
                cy.get('.govuk-radios__item').contains('A pothole in pavement');
                cy.get('.govuk-radios__item').contains('Has canal subcategory');
                cy.get('.hidden-canals-choice').contains('A pothole in pavement').should('not.exist');
                cy.get('.hidden-canals-choice').contains('Has canal subcategory').should('not.exist');
                cy.get('.hidden-highways-choice').contains('A pothole in pavement').should('not.exist');
                cy.get('.hidden-highways-choice').contains('Has canal subcategory').should('not.exist');

                // Canals hidden
                cy.get('.govuk-radios__item').contains('Boating etiquette');
                cy.get('.hidden-canals-choice').contains('Boating etiquette');
                cy.get('.hidden-highways-choice').contains('Boating etiquette').should('not.exist');

                // NH hidden
                cy.get('.govuk-radios__item').contains('Driver on phone');
                cy.get('.hidden-canals-choice').contains('Driver on phone').should('not.exist');
                cy.get('.hidden-highways-choice').contains('Driver on phone');

                cy.pickCategory('Has canal subcategory');
                cy.nextPageReporting();

                cy.pickSubcategory('Has canal subcategory', 'Not canal');
                cy.nextPageReporting();
                cy.nextPageReporting();

                cy.get('#js-councils_text').contains('These will be sent to Gloucestershire County Council');

                // Test going back
                cy.go('back');
                cy.go('back');
                cy.go('back');
                cy.go('back');
                cy.get('#js-highways').click();
                cy.nextPageReporting();
                cy.pickCategory('Driver on phone');
                cy.nextPageReporting();
                cy.nextPageReporting();
                cy.get('#js-councils_text').contains('These will be sent to National Highways');

                // FIXME Shows highways question after 'on canal' selected
                // cy.go('back');
                // cy.go('back');
                // cy.go('back');
                // cy.go('back');
                // cy.get('#js-canals').click();
                // cy.nextPageReporting();
                // cy.pickCategory('Boating etiquette');
                // cy.nextPageReporting();
                // cy.nextPageReporting();
                // cy.get('#js-councils_text').contains('These will be sent to Canal & River Trust');
            });
        });
    });
});
