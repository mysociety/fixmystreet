describe("Oxfordshire cobrand", function() {
  it("allows inspectors to instruct defects", function() {
    cy.server();
    cy.route('/report/*').as('show-report');

    cy.visit('http://oxfordshire.localhost:3001/_test/setup/oxfordshire-defect');

    cy.request({
      method: 'POST',
      url: 'http://oxfordshire.localhost:3001/auth',
      form: true,
      body: { username: 'inspector-instructor@example.org', password_sign_in: 'password' }
    });

    cy.visit('http://oxfordshire.localhost:3001/report/1');
    cy.contains('Oxfordshire');
    cy.contains('Problems nearby').click();
    cy.get('[href$="/report/1"]').last().click();
    cy.wait('@show-report');

    cy.get('#report_inspect_form').should('be.visible');
    cy.get('#js-inspect-action-scheduled').should('not.be.visible');
    cy.get('#raise_defect_yes').should('not.have.attr', 'required');

    cy.get('#report_inspect_form select[name=state]').select('Action scheduled');
    cy.get('#js-inspect-action-scheduled').should('be.visible');
    cy.get('#raise_defect_yes').should('have.attr', 'required', 'required');
    cy.get('#raise_defect_yes').click({force: true});
    cy.get('#defect_item_category').should('be.visible');

    cy.get('#report_inspect_form select[name=state]').select('No further action');
    cy.get('#js-inspect-action-scheduled').should('not.be.visible');
    cy.get('#raise_defect_yes').should('not.have.attr', 'required');

    cy.visit('http://oxfordshire.localhost:3001/_test/teardown/oxfordshire-defect');
  });
});
