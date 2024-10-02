describe('Gloucestershire cobrand', function(){
    describe('making a report as a new user', function() {
        before(function(){
            cy.server();
            cy.route('/report/new/ajax*').as('report-ajax');

            cy.visit('http://gloucestershire.localhost:3001/report/new?longitude=-2.093063&latitude=51.896268');
            cy.contains('Gloucestershire County Council');

            cy.wait('@report-ajax');
        });

        it('does not display extra message when selecting a "road" category', function(){
            cy.pickCategory('A pothole in road');
        });

        it('clicks through to photo section', function(){
            cy.nextPageReporting();
            cy.contains('Drag photos here').should('be.visible');
        });

        it('clicks through to public details page', function(){
            cy.nextPageReporting();
            cy.contains('Public details').should('be.visible');
            cy.contains('Cheltenham Borough Council').should('not.be.visible');
        });
    });
});
