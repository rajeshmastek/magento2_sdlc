/**
 * auth.setup.ts
 * Authenticates both admin and customer users, saves storage state
 * for reuse across all tests — avoids repeated login in every test.
 */
import { test as setup, expect } from '@playwright/test';
import * as fs from 'fs';

const ADMIN_FILE    = 'test-results/.auth/admin.json';
const CUSTOMER_FILE = 'test-results/.auth/customer.json';

// Ensure auth directory exists
fs.mkdirSync('test-results/.auth', { recursive: true });

setup('authenticate admin', async ({ page }) => {
  const adminUser = process.env.MAGENTO_ADMIN_USER || 'admin';
  const adminPass = process.env.MAGENTO_ADMIN_PASS || 'admin123';
  const baseUrl   = process.env.BASE_URL || 'http://localhost';

  await page.goto(`${baseUrl}/admin`);
  await page.waitForLoadState('networkidle');

  // Handle potential redirect to custom admin path
  const currentUrl = page.url();
  if (!currentUrl.includes('/admin')) {
    await page.goto(`${baseUrl}/admin_secure`);
  }

  await page.locator('input[name="login[username]"]').fill(adminUser);
  await page.locator('input[name="login[password]"]').fill(adminPass);
  await page.locator('.action-login, button[type="submit"]').first().click();
  await page.waitForLoadState('networkidle');

  // Dismiss any dashboard notices
  const dismissBtn = page.locator('.action-close, .modal-popup .action-accept');
  if (await dismissBtn.isVisible({ timeout: 3000 }).catch(() => false)) {
    await dismissBtn.click();
  }

  await expect(page.locator('.admin-user, .page-header, [data-ui-id="menu-magento-backend-dashboard"]'))
    .toBeVisible({ timeout: 15000 });

  await page.context().storageState({ path: ADMIN_FILE });
  console.log('✓ Admin authenticated');
});

setup('authenticate customer', async ({ page }) => {
  const email    = process.env.MAGENTO_CUSTOMER_EMAIL || 'test@example.com';
  const password = process.env.MAGENTO_CUSTOMER_PASS  || 'Test1234!';
  const baseUrl  = process.env.BASE_URL || 'http://localhost';

  await page.goto(`${baseUrl}/customer/account/login`);
  await page.waitForLoadState('networkidle');

  await page.locator('input[id="email"]').fill(email);
  await page.locator('input[id="pass"]').fill(password);
  await page.locator('button.action.login').click();
  await page.waitForLoadState('networkidle');

  const isLoggedIn = await page.locator('.customer-name, .logged-in').isVisible({ timeout: 10000 }).catch(() => false);
  if (!isLoggedIn) {
    // Create customer if doesn't exist
    console.warn('Customer not found — saving empty state, tests will create/login as needed');
    await page.context().storageState({ path: CUSTOMER_FILE });
    return;
  }

  await page.context().storageState({ path: CUSTOMER_FILE });
  console.log('✓ Customer authenticated');
});
