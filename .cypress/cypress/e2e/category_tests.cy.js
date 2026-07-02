describe('Basic categories', function() {
    beforeEach(function(){
        cy.intercept('/report/new/ajax*').as('report-ajax');
    });

    var categories = [
        'Abandoned vehicles',
        'Bus stops',
        'Dog fouling',
        'Fly-tipping',
        'Flyposting',
        'Flytipping',
        'Footpath/bridleway away from road',
        'Graffiti',
        'Offensive graffiti',
        'G|Licensing',
        'G|Parks',
        'Parks/landscapes',
        'Pavements',
        'Potholes',
        'Public toilets',
        'Road traffic signs',
        'Roads/highways',
        'Rubbish (refuse and recycling)',
        'Street cleaning',
        'Street lighting',
        'Street nameplates',
        'G|Streets',
        'Traffic lights',
        'Trees',
        'Other'
    ];

    it('category dropdown contains the expected values', function() {
        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.expose('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.url().should('include', '/around');
        cy.get('#map_box').click(240, 249);
        cy.wait('@report-ajax');
        cy.get('[name=category]').parent().should('be.visible');
        cy.get('#form_category_fieldset input[name="category"]').each(function (obj, i) {
            expect(obj[0].value).to.equal(categories[i]);
        });
        cy.get('#subcategory_Licensing').should('not.be.visible');
        cy.pickCategory('Licensing');
        cy.nextPageReporting();
        cy.get('#subcategory_Licensing').should('be.visible');
        cy.go('back');
        cy.pickCategory('Graffiti');
        cy.nextPageReporting();
        cy.get('#subcategory_Licensing').should('not.be.visible');
    });

    it('category dropdown contains works from new page', function() {
        cy.visit('/report/new?latitude=51.496194&longitude=-2.603439');
        cy.get('[name=category]').parent().should('be.visible');
        cy.get('#form_category_fieldset input[name="category"]').each(function (obj, i) {
            expect(obj[0].value).to.equal(categories[i]);
        });
        cy.get('#subcategory_Licensing').should('not.be.visible');
        cy.wait('@report-ajax');
        cy.pickCategory('Licensing');
        cy.nextPageReporting();
        cy.get('#subcategory_Licensing').should('be.visible');
        cy.go('back');
    });

    it('category search functions as expected', function() {
        cy.visit('/report/new?latitude=51.496194&longitude=-2.603439');
        cy.wait('@report-ajax');

        function is_visible(label) {
            cy.get('[value="' + label + '"]').parent().should('be.visible');
        }
        function is_not_visible(label) {
            cy.get('[value="' + label + '"]').parent().should('not.be.visible');
        }

        cy.get('#category-filter').type('Fly');
        is_not_visible('Abandoned vehicles');
        is_not_visible("Bus stops");
        is_visible("Flyposting");
        is_visible("Flytipping");
        is_visible("Fly-tipping");

        cy.get('#category-filter').type('{selectAll}Flyt');
        is_visible("Flytipping");
        is_visible("Fly-tipping");
        is_not_visible("Flyposting");

        cy.get('#category-filter').type('{selectAll}Fly-t');
        is_visible("Flytipping");
        is_visible("Fly-tipping");
        is_visible("Flyposting");

        cy.get('#category-filter').type('{selectAll}Abad');
        is_visible('Abandoned vehicles');

        cy.get('#category-filter').type('{selectAll}Abadn');
        is_visible('Abandoned vehicles');

        cy.get('#category-filter').type('{selectAll}Abado');
        is_visible('Abandoned vehicles');

        cy.get('#category-filter').type('{selectAll}Abadoe');
        cy.contains('Please try another search');
        is_not_visible('Abandoned vehicles');
        cy.get('.js-reporting-page--next:visible').should('be.disabled');

        cy.get('#category-filter').type('{backspace}');
        cy.get('#filter-category-error').should('not.exist'); // Contains the text for 'Please try another search'
        is_visible('Abandoned vehicles');
        cy.get('.js-reporting-page--next:visible').should('not.be.disabled');

        cy.get('#category-filter').type('{selectAll}L');
        is_not_visible("Bus stops");
        is_visible('Abandoned vehicles');
        is_visible("Dog fouling");
        is_visible("G|Licensing");
        is_visible("Dropped Kerbs");
        is_visible("Skips");
        // Hidden by scroll:
        // cy.get('[value="Street lighting"]').should('be.visible');
        // cy.get('[value="Traffic lights"]').should('be.visible');

        cy.get('#category-filter').type('{selectAll}Lig');
        is_not_visible('Abandoned vehicles');
        is_not_visible("Dog fouling");
        is_not_visible("G|Licensing");
        is_visible("Street lighting");
        is_visible("Traffic lights");

        cy.get('#category-filter').type('{selectAll}Dr K');
        is_visible("Dropped Kerbs");

    });
});
