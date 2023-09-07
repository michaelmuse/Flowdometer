const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  moduleNameMapper: {
    "^c/modal$": "<rootDir>/force-app/main/default/lwc/__mocks__/modal.js"
    // ... other mappings
  }
};
