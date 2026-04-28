// jshint esversion: 6

describe('Admin pages', function() {
    beforeEach(function(){
        // Sign in as superuser
        cy.visit('http://borsetshire.localhost:3001/auth');
        cy.contains('Super user').click();
    });

    it('lets you add multiple option extra questions at once', function(){
        cy.visit('http://borsetshire.localhost:3001/admin/body/1/Graffiti');
        add_field();
        add_field();
        cy.get('#state-confirmed').click();
        cy.get('[value="Save changes"]').click();
    });
});

function add_field() {
    cy.get('button.js-metadata-item-add').click();
    var id = cy.contains('New field').parents('.js-metadata-item').invoke('attr', 'data-i').then(function(id) {
        cy.get(`#metadata-${id}-code`).type(`question${id}`);
        cy.get(`#metadata-${id}-datatype`).select('singlevaluelist');
        add_option(id, 1, 'y', 'Yes');
        add_option(id, 2, 'n', 'No');
        cy.get('.js-metadata-item-header-title').contains(`question${id}`).parent().click(); // Hide it
    });
}

function add_option(id, option_id, key, val) {
    cy.get('button.js-metadata-option-add:visible').click();
    cy.get(`#metadata-${id}-values-${option_id}-key`).type(`key${id}-${key}`);
    cy.get(`#metadata-${id}-values-${option_id}-name`).type(val);
}
