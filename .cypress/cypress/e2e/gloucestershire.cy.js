describe('Gloucestershire cobrand', function(){
    it('makes a report as a new user', function() {
        cy.intercept('/report/new/ajax*').as('report-ajax');

        cy.visit('http://gloucestershire.localhost:3001/report/new?longitude=-2.093063&latitude=51.896268');
        cy.contains('Gloucestershire County Council');

        cy.wait('@report-ajax');

        // does not display extra message when selecting a "road" category
        cy.pickCategory('A pothole in road');

        // clicks through to photo section
        cy.nextPageReporting();
        cy.contains('Drag photos here').should('be.visible');

        // clicks through to public details page
        cy.nextPageReporting();
        cy.contains('Public details').should('be.visible');
        cy.contains('Cheltenham Borough Council').should('not.exist');
    });
});
