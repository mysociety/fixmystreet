describe('Basic categories', function() {
    before(function(){
        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
    });

    var categories = [
        'Abandoned vehicles',
        'Bus stops',
        'Dog fouling',
        'Flyposting',
        'Flytipping',
        'Footpath/bridleway away from road',
        'Graffiti',
        'Offensive graffiti',
        'Licensing',
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
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
        cy.url().should('include', '/around');
        cy.get('#map_box').click(240, 249);
        cy.wait('@report-ajax');
        cy.get('[name=category]').should('be.visible');
        cy.get('#form_category_fieldset input').each(function (obj, i) {
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
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
        cy.visit('/report/new?latitude=51.496194&longitude=-2.603439');
        cy.get('[name=category]').should('be.visible');
        cy.get('#form_category_fieldset input').each(function (obj, i) {
            expect(obj[0].value).to.equal(categories[i]);
        });
        cy.get('#subcategory_Licensing').should('not.be.visible');
        cy.wait('@report-ajax');
        cy.pickCategory('Licensing');
        cy.nextPageReporting();
        cy.get('#subcategory_Licensing').should('be.visible');
    });
});
