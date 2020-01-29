describe('new report form', function() {

  beforeEach(function() {
    cy.server();
    cy.route('/report/new/ajax*').as('report-ajax');
    cy.visit('http://peterborough.localhost:3001/');
    cy.contains('Peterborough');
    cy.get('[name=pc]').type('PE1 1HF');
    cy.get('[name=pc]').parents('form').submit();
    cy.get('#map_box').click();
    cy.wait('@report-ajax');
  });

  it('is hidden when emergency option is yes', function() {
    cy.get('select:eq(4)').select('Fallen branch');
    cy.get('#form_emergency').select('yes');
    cy.get('#js-category-stopper').should('contain', 'Please phone customer services to report this problem.');
    cy.get('.js-hide-if-invalid-category').should('be.hidden');
    cy.get('#form_emergency').select('no');
    cy.get('#js-category-stopper').should('not.contain', 'Please phone customer services to report this problem.');
    cy.get('.js-hide-if-invalid-category').should('be.visible');
  });

  it('is hidden when private land option is yes', function() {
    cy.get('select:eq(4)').select('Fallen branch');
    cy.get('#form_private_land').select('yes');
    cy.get('#js-category-stopper').should('contain', 'The council do not have powers to address issues on private land.');
    cy.get('.js-hide-if-invalid-category').should('be.hidden');
    cy.get('#form_private_land').select('no');
    cy.get('#js-category-stopper').should('not.contain', 'The council do not have powers to address issues on private land.');
    cy.get('.js-hide-if-invalid-category').should('be.visible');
  });

});
