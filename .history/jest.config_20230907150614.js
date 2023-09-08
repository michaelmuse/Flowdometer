const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  testEnvironment: "jsdom",
  preset: "@lwc/jest-preset",
  moduleNameMapper: {
    "^c/(.*)$": "<rootDir>/force-app/main/default/lwc/$1/$1.js"
  },
  testPathIgnorePatterns: ["/node_modules/", "/.history/"],
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"]
};
