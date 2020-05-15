describe("Oxfordshire cobrand", function() {
  it("allows inspectors to instruct defects", function() {
    cy.server();
    cy.request({
      method: 'POST',
      url: 'http://oxfordshire.localhost:3001/auth',
      form: true,
      body: { username: 'inspector-instructor@example.org', password_sign_in: 'password' }
    });
    cy.visit('http://oxfordshire.localhost:3001/report/1');
    cy.contains('Oxfordshire');

    cy.get('#report_inspect_form').should('be.visible');
    cy.get('#js-inspect-action-scheduled').should('not.be.visible');
    cy.get('#raise_defect_yes').should('not.have.attr', 'required');

    cy.get('#report_inspect_form select[name=state]').select('Action scheduled');
    cy.get('#js-inspect-action-scheduled').should('be.visible');
    cy.get('#raise_defect_yes').should('have.attr', 'required', 'required');

    cy.get('#report_inspect_form select[name=state]').select('No further action');
    cy.get('#js-inspect-action-scheduled').should('not.be.visible');
    cy.get('#raise_defect_yes').should('not.have.attr', 'required');
  });
});
