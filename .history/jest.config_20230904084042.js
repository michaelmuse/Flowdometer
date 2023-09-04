const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    // Explicitly set the test environment to "jsdom"
    preset: '@lwc/jest-preset',
    testEnvironment: 'jsdom',
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver'],
    moduleNameMapper: {
        '^c/(.*)$': '<rootDir>/force-app/main/default/lwc/$1',
        // Add other mappings here if needed
    },
    testPathIgnorePatterns: ['/node_modules/', '/.history/']
};