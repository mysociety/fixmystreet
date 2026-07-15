var landTypeCases = [
    { private: false, category: 'General fly tipping', message: null },
    { private: false, category: 'Non offensive graffiti', message: null },
    { private: false, category: 'Abandoned vehicles', message: null },
    { private: false, group: 'Street cleansing', category: 'Street sweeping', message: null },
    { private: false, group: 'Grounds maintenance', category: 'Grass cutting', message: null },
    { private: true, category: 'General fly tipping',
      message: 'The area selected is not owned or maintained by Peterborough City Council' },
    { private: true, category: 'Non offensive graffiti',
      message: 'For graffiti on private land this would be deemed' },
    { private: true, category: 'Abandoned vehicles',
      message: 'Unfortunately, as this car is on private land' },
    { private: true, group: 'Street cleansing', category: 'Street sweeping',
      message: 'it is not the responsibility of the Council to provide Street Cleansing services' },
    { private: true, group: 'Grounds maintenance', category: 'Grass cutting',
      message: 'it is not the responsibility of the Council to provide Grounds Maintenance services' },
];

function checkLandTypeMessages(host) {
    landTypeCases.forEach(function(testCase) {
        var coords = testCase.private ?
            'longitude=-0.241841&latitude=52.570792' :
            'longitude=-0.242007&latitude=52.571903';
        cy.visit('http://' + host + '/report/new?' + coords);
        cy.wait('@report-ajax');
        cy.pickCategory(testCase.group || testCase.category);
        if (testCase.message) {
            cy.get('.pre-button-messaging:visible').should('contain', testCase.message);
        } else {
            cy.get('.pre-button-messaging:visible').should('not.exist');
        }
        if (testCase.private) {
            cy.get('.js-reporting-page--next:visible').should('be.disabled');
        } else {
            cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
        }
    });
}

describe('new report form', function() {

  beforeEach(function() {
    cy.intercept('/report/new/ajax*').as('report-ajax');
    cy.intercept("**/peterborough.assets/4/*", {fixture: 'peterborough_pcc.json'}).as('pcc');
    cy.intercept("**/peterborough.assets/3/*", {fixture: 'peterborough_non_pcc.json'}).as('non_pcc');
    cy.visit('http://peterborough.localhost:3001/');
    cy.contains('Peterborough');
    cy.get('[name=pc]').type('PE1 1HF');
    cy.get('[name=pc]').parents('form').submit();
    cy.get('#map_box').click();
    cy.wait('@report-ajax');
  });

  it('is hidden when emergency option is yes', function() {
    cy.pickCategory('Fallen branch');
    cy.nextPageReporting();
    cy.get('[name=emergency][value=yes]').click();
    cy.get('.pre-button-messaging:visible').should('contain', 'Please phone customer services to report this problem.');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('[name=emergency][value=no]').click();
    cy.get('.pre-button-messaging:visible').should('not.exist');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
  });

  it('is hidden when private land option is yes', function() {
    cy.pickCategory('Fallen branch');
    cy.nextPageReporting();
    cy.get('[name=private_land][value=yes]').click();
    cy.get('.pre-button-messaging:visible').should('contain', 'The council do not have powers to address issues on private land.');
    cy.get('.js-reporting-page--next:visible').should('be.disabled');
    cy.get('[name=private_land][value=no]').click();
    cy.get('.pre-button-messaging:visible').should('not.exist');
    cy.get('.js-reporting-page--next:visible').should('not.be.disabled');
  });

  it('flytipping/graffiti/grounds maintenance/street cleansing categories handle land types correctly', function() {
    checkLandTypeMessages('peterborough.localhost:3001');
  });

  it('correctly changes the asset select message', function() {
    cy.pickCategory('Street lighting');
    cy.get('.pre-button-messaging').should('contain', 'Please select a light from the map');
    cy.pickCategory('Trees');
    cy.get('.pre-button-messaging').should('contain', 'Please select a tree from the map');
  });
});

describe('Roadworks', function() {
  beforeEach(function() {
    cy.intercept('/report/new/ajax*').as('report-ajax');
    cy.intercept("**/peterborough.assets/4/*", {fixture: 'peterborough_pcc.json'}).as('pcc');
    cy.intercept("**/peterborough.assets/3/*", {fixture: 'peterborough_non_pcc.json'}).as('non_pcc');
    cy.intercept('/streetmanager.php**', {fixture: 'peterborough_roadworks.json'}).as('roadworks');
    cy.visit('http://peterborough.localhost:3001/');
    cy.contains('Peterborough');
    cy.get('[name=pc]').type('PE1 1HF');
    cy.get('[name=pc]').parents('form').submit();
    cy.get('#map_box').click();
    cy.wait('@report-ajax');
  });

  it('displays nearby roadworks', function() {
    cy.wait('@roadworks');
    cy.pickCategory('Pothole');
    cy.nextPageReporting();
    cy.contains('Roadworks are scheduled near this location').should('be.visible');
    cy.contains('Parapet improvement').should('be.visible');
    cy.go('back');
    cy.pickCategory('Fallen branch');
    cy.nextPageReporting();
    cy.should('not.contain', 'Roadworks are scheduled near this location');
  });
});

describe('National site tests', function() {
  it('flytipping/graffiti/grounds maintenance/street cleansing categories handle land types correctly on .com', function() {
    cy.intercept('/report/new/ajax*').as('report-ajax');
    cy.intercept("**/peterborough.assets/4/*", {fixture: 'peterborough_pcc.json'}).as('pcc');
    cy.intercept("**/peterborough.assets/3/*", {fixture: 'peterborough_non_pcc.json'}).as('non_pcc');

    checkLandTypeMessages('fixmystreet.localhost:3001');
  });

});
