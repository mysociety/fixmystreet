describe('Dashboard page', function() {
    beforeEach(function(){
        // Sign in as superuser
        cy.visit('http://borsetshire.localhost:3001/auth');
        cy.contains('Super user').click();
    });

    it('no deleted categories', function(){
        // Make sure Graffiti is confirmed (we delete later)
        cy.visit('http://borsetshire.localhost:3001/admin/body/1/Graffiti');
        cy.get('#state-confirmed').click();
        cy.get('[value="Save changes"]').click();

        cy.visit('http://borsetshire.localhost:3001/dashboard');

        // Check that deleted categories button is not present
        cy.get('#toggle-deleted-contacts-btn').should('not.exist');

        // Initially visible categories
        cy.get('tr:visible').should('contain', 'Graffiti');
        cy.get('tr:visible').should('contain', 'Other');
        cy.get('tr:visible').should('contain', 'Potholes');
        cy.get('tr:visible').should('contain', 'Street lighting');

        // Intially hidden categories & headings (groups)
        cy.get('tr:visible').should('not.contain', 'Abandoned vehicles');
        cy.get('tr:visible').should('not.contain', 'Licensing');
        cy.get('tr:visible').should('not.contain', 'Waste');
        cy.get('tr:visible').should('not.contain', 'Multiple');

        cy.get('.subtotal td').last().should('contain', 21);

        // Click 'zero reports' button
        cy.get('#toggle-zeroes-btn').click();
        cy.get('tr:visible').should('contain', 'Abandoned vehicles');
        cy.get('tr:visible').should('contain', 'Licensing');
        cy.get('tr:visible').should('contain', 'Waste');
        cy.get('tr:visible').should('contain', 'Multiple');

        // Check we can re-hide
        cy.get('#toggle-zeroes-btn').click();
        cy.get('tr:visible').should('not.contain', 'Abandoned vehicles');
        cy.get('tr:visible').should('not.contain', 'Licensing');
        cy.get('tr:visible').should('not.contain', 'Waste');
        cy.get('tr:visible').should('not.contain', 'Multiple');
    });

    it('has deleted category', function(){
        // Set Graffiti to deleted
        cy.visit('http://borsetshire.localhost:3001/admin/body/1/Graffiti');
        cy.get('#state-deleted').click();
        cy.get('[value="Save changes"]').click();

        // Check button visible on dashboard
        cy.visit('http://borsetshire.localhost:3001/dashboard');
        cy.get('#toggle-deleted-contacts-btn').should('exist');

        // Initially visible categories
        cy.get('tr:visible').should('contain', 'Other');
        cy.get('tr:visible').should('contain', 'Potholes');
        cy.get('tr:visible').should('contain', 'Street lighting');

        // Intially hidden categories & headings (groups)
        cy.get('tr:visible').should('not.contain', 'Graffiti');
        cy.get('tr:visible').should('not.contain', 'Abandoned vehicles');
        cy.get('tr:visible').should('not.contain', 'Licensing');
        cy.get('tr:visible').should('not.contain', 'Waste');
        cy.get('tr:visible').should('not.contain', 'Multiple');

        // Check total is still the same even though deleted not visible
        cy.get('.subtotal td').last().should('contain', 21);

        // Click deleted categories morning
        cy.get('#toggle-deleted-contacts-btn').click();

        // Deleted 'Graffiti' should show, but not other hidden ones
        cy.get('tr:visible').should('contain', 'Graffiti');
        cy.get('tr:visible').should('not.contain', 'Abandoned vehicles');
        cy.get('tr:visible').should('not.contain', 'Licensing');
        cy.get('tr:visible').should('not.contain', 'Waste');
        cy.get('tr:visible').should('not.contain', 'Multiple');

        // Click 'category' tab
        cy.get('[title="Group by Category"]').click();

        // Everything back to hidden
        cy.get('tr:visible').should('not.contain', 'Graffiti');
        cy.get('tr:visible').should('not.contain', 'Abandoned vehicles');
        cy.get('tr:visible').should('not.contain', 'Licensing');
        cy.get('tr:visible').should('not.contain', 'Waste');
        cy.get('tr:visible').should('not.contain', 'Multiple');

        // Click both buttons
        cy.get('#toggle-zeroes-btn').click();
        cy.get('#toggle-deleted-contacts-btn').click();

        cy.get('tr:visible').should('contain', 'Graffiti');
        cy.get('tr:visible').should('contain', 'Abandoned vehicles');
        cy.get('tr:visible').should('contain', 'Licensing');
        cy.get('tr:visible').should('contain', 'Waste');
        cy.get('tr:visible').should('contain', 'Multiple');

        // Check other tabs do not have buttons
        cy.get('[title="Group by State"]').click();
        cy.get('#toggle-zeroes-btn').should('not.exist');
        cy.get('#toggle-deleted-contacts-btn').should('not.exist');

        // Search by particular categories:
        // - has reports
        cy.visit('http://borsetshire.localhost:3001/dashboard');
        cy.get('.multi-select-button').eq(1).click();
        cy.get('input[value=Potholes]').click();
        cy.get('[value="Look up"]').click();
        cy.get('tr:visible').should('contain', 'Potholes');
        cy.get('tr:visible').should('not.contain', 'Graffiti');
        cy.get('tr:visible').should('not.contain', 'Other');
        cy.get('tr:visible').should('not.contain', 'Street lighting');
        cy.get('tr:visible').should('not.contain', 'Abandoned vehicles');
        cy.get('tr:visible').should('not.contain', 'Licensing');
        cy.get('tr:visible').should('not.contain', 'Waste');
        cy.get('tr:visible').should('not.contain', 'Multiple');
        cy.get('.subtotal td').last().should('contain', 6);

        // - has no reports
        cy.visit('http://borsetshire.localhost:3001/dashboard');
        cy.get('.multi-select-button').eq(1).click();
        cy.get('input[value="group-Licensing"]').click();
        cy.get('[value="Look up"]').click();
        cy.get('tr:visible').should('contain', 'Licensing');
        cy.get('tr:visible').should('contain', 'Dropped Kerbs');
        cy.get('tr:visible').should('contain', 'Skips');
        cy.get('tr:visible').should('not.contain', 'Graffiti');
        cy.get('tr:visible').should('not.contain', 'Other');
        cy.get('tr:visible').should('not.contain', 'Potholes');
        cy.get('tr:visible').should('not.contain', 'Street lighting');
        cy.get('tr:visible').should('not.contain', 'Abandoned vehicles');
        cy.get('tr:visible').should('not.contain', 'Waste');
        cy.get('tr:visible').should('not.contain', 'Multiple');
        cy.get('.subtotal td').last().should('contain', 0);

        cy.visit('http://borsetshire.localhost:3001/dashboard');
        cy.get('.multi-select-button').eq(1).click();
        cy.get('input[value="Skips"]').click();
        cy.get('[value="Look up"]').click();
        cy.get('tr:visible').should('contain', 'Licensing');
        cy.get('tr:visible').should('not.contain', 'Dropped Kerbs');
        cy.get('tr:visible').should('contain', 'Skips');
        cy.get('tr:visible').should('not.contain', 'Graffiti');
        cy.get('tr:visible').should('not.contain', 'Other');
        cy.get('tr:visible').should('not.contain', 'Potholes');
        cy.get('tr:visible').should('not.contain', 'Street lighting');
        cy.get('tr:visible').should('not.contain', 'Abandoned vehicles');
        cy.get('tr:visible').should('not.contain', 'Waste');
        cy.get('tr:visible').should('not.contain', 'Multiple');
        cy.get('.subtotal td').last().should('contain', 0);

        // - deleted
        cy.visit('http://borsetshire.localhost:3001/dashboard');
        cy.get('.multi-select-button').eq(1).click();
        cy.get('input[value="Graffiti"]').click();
        cy.get('[value="Look up"]').click();
        cy.get('tr:visible').should('contain', 'Graffiti');
        cy.get('tr:visible').should('not.contain', 'Potholes');
        cy.get('tr:visible').should('not.contain', 'Other');
        cy.get('tr:visible').should('not.contain', 'Street lighting');
        cy.get('tr:visible').should('not.contain', 'Abandoned vehicles');
        cy.get('tr:visible').should('not.contain', 'Licensing');
        cy.get('tr:visible').should('not.contain', 'Waste');
        cy.get('tr:visible').should('not.contain', 'Multiple');
        cy.get('.subtotal td').last().should('contain', 5);

        // Undo category deletion
        cy.visit('http://borsetshire.localhost:3001/admin/body/1/Graffiti');
        cy.get('#state-confirmed').click();
        cy.get('[value="Save changes"]').click();
    });
});
