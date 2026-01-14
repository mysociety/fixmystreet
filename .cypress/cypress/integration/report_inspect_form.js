describe('Changing category or group on report inspect form', function() {
    beforeEach(function(){
        // Sign in as superuser
        cy.visit('http://borsetshire.localhost:3001/auth');
        cy.contains('Super user').click();
    });

    it('on /report page', function() {
        cy.visit('http://borsetshire.localhost:3001/report/1');

        cy.get('[name=priority]').should('not.contain', 'Priority 1');
        cy.get('[name=priority]').should('contain', 'Priority 2');
        cy.get('[name=priority]').should('contain', 'Priority 3');
        cy.get('[name=priority]').should('not.contain', 'Priority 4');

        // Category with no group
        cy.get('[name=category]').select('Abandoned vehicles');
        // For some reason, two state dropdowns are found
        // and the first is not visible (?).
        // Similarly for response_template.
        cy.get('[name=state]').last().select('Not responsible');
        cy.get('[name=response_template]').last().should('have.value', 'This report is not the responsibility of the council and will be passed to the relevant organisation.');
        cy.get('[name=priority]').should('contain', 'Priority 1');
        cy.get('[name=priority]').should('contain', 'Priority 2');
        cy.get('[name=priority]').should('contain', 'Priority 3');
        cy.get('[name=priority]').should('not.contain', 'Priority 4');

        // Category with single group
        cy.get('[name=category]').select('Skips');
        cy.get('[name=state]').last().select('Not responsible');
        cy.get('[name=response_template]').last().should('have.value', 'This report with a category under one group is not the responsibility of the council.');
        cy.get('[name=priority]').should('not.contain', 'Priority 1');
        cy.get('[name=priority]').should('contain', 'Priority 2');
        cy.get('[name=priority]').should('contain', 'Priority 3');
        cy.get('[name=priority]').should('not.contain', 'Priority 4');

        // Category with multiple groups
        cy.get('[name=category]').select('Streets__Litter');
        cy.get('[name=state]').last().select('Not responsible');
        cy.get('[name=response_template]').last().should('have.value', 'This report with a category under multiple groups is not the responsibility of the council.');
        cy.get('[name=priority]').should('not.contain', 'Priority 1');
        cy.get('[name=priority]').should('contain', 'Priority 2');
        cy.get('[name=priority]').should('contain', 'Priority 3');
        cy.get('[name=priority]').should('contain', 'Priority 4');

        // Check correct group is saved & selected
        cy.get('[name="save"]').click();
        cy.visit('http://borsetshire.localhost:3001/report/1');
        cy.get('[name=category]').should('have.value', 'Streets__Litter');
    });

    it('on /admin/report_edit page', function() {
        cy.visit('http://borsetshire.localhost:3001/admin/report_edit/1');

        // No response template option; just test group selection
        cy.get('[name=category]').should('have.value', 'Streets__Litter');
        cy.get('[name=category]').select('Parks__Litter');
        cy.get('[name="Submit changes"]').first().click();
        cy.get('[name=category]').should('have.value', 'Parks__Litter');
    });
});
