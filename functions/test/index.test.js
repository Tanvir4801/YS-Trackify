const test = require('firebase-functions-test')();
const functions = require('../index.js');

describe('Cloud Functions', () => {
  afterAll(() => {
    test.cleanup();
  });

  it('loads functions without crashing', () => {
    expect(functions.labourLogin).toBeDefined();
    expect(functions.validateAndMarkAttendance).toBeDefined();
  });
});
