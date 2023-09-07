const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  // Explicitly set the test environment to "jsdom"
  testEnvironment: "jsdom",
  preset: "@lwc/jest-preset", // Merged from file 2
  moduleNameMapper: {
    "^c/(.*)$": "<rootDir>/force-app/main/default/lwc/$1", // Merged from file 2
    // Add other mappings here if needed
  },
  testPathIgnorePatterns: ["/node_modules/", "/.history/"],
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
};