describe('Basic categories', function() {
    before(function(){
        cy.visit('/');
        cy.contains('Go');
        cy.get('[name=pc]').type(Cypress.env('postcode'));
        cy.get('[name=pc]').parents('form').submit();
    });

    var categories = [
        '-- Pick a category --',
        'Abandoned vehicles',
        'Bins',
        'Bus stops',
        'Dog fouling',
        'Flyposting',
        'Flytipping',
        'Footpath/bridleway away from road',
        'Graffiti',
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
        cy.get('[name=category]').should('not.be.visible');
        cy.get('select:eq(3) option').each(function (obj, i) {
            expect(obj[0].value).to.equal(categories[i]);
        });
        cy.get('#subcategory_Bins').should('not.be.visible');
        cy.get('select:eq(3)').select('Bins');
        cy.get('#subcategory_Bins').should('be.visible');
        cy.get('select:eq(3)').select('Graffiti');
        cy.get('#subcategory_Bins').should('not.be.visible');
    });

    it('category dropdown contains works from new page', function() {
        cy.server();
        cy.route('/report/new/ajax*').as('report-ajax');
        cy.visit('/report/new?latitude=51.496194&longitude=-2.603439');
        cy.get('[name=category]').should('not.be.visible');
        cy.get('select:eq(1) option').each(function (obj, i) {
            expect(obj[0].value).to.equal(categories[i]);
        });
        cy.get('#subcategory_Bins').should('not.be.visible');
        cy.wait('@report-ajax');
        cy.get('select:eq(1)').select('Bins');
        cy.get('#subcategory_Bins').should('be.visible');
    });
});
