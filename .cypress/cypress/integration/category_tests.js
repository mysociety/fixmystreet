describe('Basic categories', function() {
    beforeEach(function(){
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
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
        'Traffic lights',
        'Trees',
        'Other'
    ];

    it('category dropdown contains the expected values', function() {
        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
        cy.url().should('include', '/around');
        cy.get('#map_box').click(240, 249);
        cy.wait('@report-ajax');
        cy.get('[name=category]').should('be.visible');
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
        cy.get('[name=category]').should('be.visible');
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

        cy.get('#category-filter').type('Fly');
        cy.get('[value="Abandoned vehicles"]').should('not.be.visible');
        cy.get('[value="Bus stops"]').should('not.be.visible');
        cy.get('[value="Flyposting"]').should('be.visible');
        cy.get('[value="Flytipping"]').should('be.visible');
        cy.get('[value="Fly-tipping"]').should('be.visible');

        cy.get('#category-filter').type('{selectAll}Flyt');
        cy.get('[value="Flytipping"]').should('be.visible');
        cy.get('[value="Fly-tipping"]').should('be.visible');
        cy.get('[value="Flyposting"]').should('not.be.visible');

        cy.get('#category-filter').type('{selectAll}Fly-t');
        cy.get('[value="Flytipping"]').should('be.visible');
        cy.get('[value="Fly-tipping"]').should('be.visible');
        cy.get('[value="Flyposting"]').should('be.visible');

        cy.get('#category-filter').type('{selectAll}Abad');
        cy.get('[value="Abandoned vehicles"]').should('be.visible');

        cy.get('#category-filter').type('{selectAll}Abadn');
        cy.get('[value="Abandoned vehicles"]').should('be.visible');

        cy.get('#category-filter').type('{selectAll}Abado');
        cy.get('[value="Abandoned vehicles"]').should('be.visible');

        cy.get('#category-filter').type('{selectAll}Abadoe');
        cy.contains('Please try another search');
        cy.get('[value="Abandoned vehicles"]').should('not.be.visible');
        cy.get('.js-reporting-page--next:visible').should('be.disabled');

        cy.get('#category-filter').type('{backspace}');
        cy.get('#filter-category-error').should('not.exist'); // Contains the text for 'Please try another search'
        cy.get('[value="Abandoned vehicles"]').should('be.visible');
        cy.get('.js-reporting-page--next:visible').should('not.be.disabled');

        cy.get('#category-filter').type('{selectAll}L');
        cy.get('[value="Bus stops"]').should('not.be.visible');
        cy.get('[value="Abandoned vehicles"]').should('be.visible');
        cy.get('[value="Dog fouling"]').should('be.visible');
        cy.get('[value="G|Licensing"]').should('be.visible');
        cy.get('[value="Dropped Kerbs"]').should('be.visible');
        cy.get('[value="Skips"]').should('be.visible');
        // Hidden by scroll:
        // cy.get('[value="Street lighting"]').should('be.visible');
        // cy.get('[value="Traffic lights"]').should('be.visible');

        cy.get('#category-filter').type('{selectAll}Lig');
        cy.get('[value="Abandoned vehicles"]').should('not.be.visible');
        cy.get('[value="Dog fouling"]').should('not.be.visible');
        cy.get('[value="G|Licensing"]').should('not.be.visible');
        cy.get('[value="Street lighting"]').should('be.visible');
        cy.get('[value="Traffic lights"]').should('be.visible');

        cy.get('#category-filter').type('{selectAll}Dr K');
        cy.get('[value="Dropped Kerbs"]').should('be.visible');

    });
});
