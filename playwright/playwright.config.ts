import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for Magento 2.4.9 test suite.
 * Tests run against the AWS-deployed Magento instance.
 */
export default defineConfig({
  testDir: './tests',
  fullyParallel: false,          // Magento needs sequential cart/order tests
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : 1,
  timeout: 60_000,
  expect: { timeout: 15_000 },

  reporter: [
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
    ['list'],
  ],

  use: {
    baseURL:     process.env.BASE_URL || 'http://localhost',
    trace:       'on-first-retry',
    screenshot:  'only-on-failure',
    video:       'on-first-retry',
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
    ignoreHTTPSErrors: true,
    extraHTTPHeaders: {
      'Accept-Language': 'en-US,en;q=0.9',
    },
  },

  projects: [
    // Setup: authenticate admin and customer, save storage state
    {
      name: 'setup',
      testMatch: '**/auth.setup.ts',
    },
    // Desktop Chrome — most tests run here
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'test-results/.auth/customer.json',
      },
      dependencies: ['setup'],
      testIgnore: '**/admin/**',
    },
    // Admin tests use admin storage state
    {
      name: 'admin',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'test-results/.auth/admin.json',
      },
      dependencies: ['setup'],
      testMatch: '**/admin/**',
    },
    // Mobile viewport
    {
      name: 'mobile',
      use: {
        ...devices['iPhone 13'],
        storageState: 'test-results/.auth/customer.json',
      },
      dependencies: ['setup'],
      testMatch: '**/mobile/**',
    },
  ],

  webServer: process.env.CI ? undefined : {
    command: 'echo "Using remote Magento instance"',
    url: process.env.BASE_URL || 'http://localhost',
    reuseExistingServer: true,
  },

  outputDir: 'test-results/artifacts',
  preserveOutput: 'failures-only',
});
