const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver'],
    moduleNameMapper: {
      '^c/modal$': '<rootDir>/force-app/main/default/lwc/mocks/modal.js',
      // ... other mappings
    },
  };
  