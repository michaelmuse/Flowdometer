const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  // Explicitly set the test environment to "jsdom"
  testEnvironment: "jsdom",
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  moduleNameMapper: {
    "^c/modal$": "<rootDir>/force-app/main/default/lwc/__tests__/modal.mock.js"
    // ... other mappings
  },
  testPathIgnorePatterns: ["/node_modules/", "/.history/"]
};
