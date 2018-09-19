describe('Filtering around page', function() {
    before(function(){
        cy.visit('/reports/Borsetshire');
        cy.contains('Borsetshire');
    });

    it('allows me to filter by report status', function() {
        cy.contains('1 to 14 of 14');
        cy.get('.multi-select-button:first').click();
        cy.get('#status_0').click();
        cy.get('#status_1').click();
        cy.contains('1 to 3 of 3');
        cy.contains('Lights out in tunnel');
        cy.url().should('include', 'status=closed');
        cy.get('#status_2').click();
        cy.contains('1 to 6 of 6');
        cy.contains('Loose drain cover');
        cy.url().should('include', 'status=closed%2Cfixed');
        cy.get('#status_preset_0').click();
        cy.get('#status_0').should('be.checked');
        cy.get('#status_1').should('be.checked');
        cy.get('#status_2').should('be.checked');
        cy.contains('1 to 20 of 20');
    });

    it('allows me to filter by report category', function() {
        cy.visit('/reports/Borsetshire');
        cy.contains('1 to 14 of 14');
        cy.get('.multi-select-button:eq(1)').click();
        cy.get('input[value=Graffiti]').click();
        cy.contains('1 to 14 of 14');
        cy.contains('Graffiti on the bridge');
        cy.get('input[value=Graffiti]').click();
        cy.get('input[value=Other]').click();
        cy.contains('1 to 2 of 2');
        cy.contains('Full litter bins');
        cy.should('not.contain', 'Graffiti on the bridge');
    });


    it('allows me to sort', function() {
        cy.server();
        cy.route('/reports/Borsetshire\?ajax*').as('update-results');
        cy.visit('/reports/Borsetshire');
        cy.contains('1 to 14 of 14');
        cy.get('#sort').select('created-desc');
        cy.url().should('include', 'sort=created-desc');
        cy.wait('@update-results');
        cy.get('.item-list__heading:first').contains('Large pothole');
        cy.get('#sort').select('created-asc');
        cy.wait('@update-results');
        cy.get('.item-list__heading:first').contains('Full litter bins');
        cy.get('#sort').select('updated-asc');
        cy.wait('@update-results');
        cy.get('.item-list__heading:first').contains('Full litter bins');
        cy.get('#sort').select('updated-desc');
        cy.wait('@update-results');
        cy.get('.item-list__heading:first').contains('Full litter bins');
        cy.get('#sort').select('comments-desc');
        cy.wait('@update-results:first');
        cy.get('.item-list__heading').contains('Full litter bins');
    });
});
