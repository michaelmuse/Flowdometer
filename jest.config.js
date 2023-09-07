//F:\Muse Operations Drive\Projects\Flowdometer\jest.config.js
const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  // Explicitly set the test environment to "jsdom"
  testEnvironment: "jsdom",
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  moduleNameMapper: {
    "^c/(.*)$": "<rootDir>/force-app/main/default/lwc/$1/$1.js"
    // Add other mappings here if needed
  },
  testPathIgnorePatterns: ["/node_modules/", "/.history/"]
};
