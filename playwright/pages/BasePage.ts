/**
 * pages/BasePage.ts
 * Base page object with common Magento 2.4.9 interactions.
 * All page objects extend this class.
 */
import { Page, Locator, expect } from '@playwright/test';

export class BasePage {
  readonly page: Page;
  readonly baseUrl: string;

  constructor(page: Page) {
    this.page    = page;
    this.baseUrl = process.env.BASE_URL || 'http://localhost';
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  async goto(path: string): Promise<void> {
    await this.page.goto(`${this.baseUrl}${path}`);
    await this.page.waitForLoadState('networkidle');
    await this.dismissModals();
  }

  async dismissModals(): Promise<void> {
    const closeBtn = this.page.locator(
      '.modal-popup.confirm .action-dismiss, ' +
      '[data-role="closeBtn"], ' +
      '.modal-popup .action-close'
    ).first();
    if (await closeBtn.isVisible({ timeout: 1500 }).catch(() => false)) {
      await closeBtn.click({ timeout: 2000 }).catch(() => {});
    }
  }

  // ── Login helpers ─────────────────────────────────────────────────────────
  async loginAsCustomer(email?: string, password?: string): Promise<void> {
    await this.goto('/customer/account/login');
    await this.page.locator('input[id="email"]').fill(email || process.env.MAGENTO_CUSTOMER_EMAIL || 'test@example.com');
    await this.page.locator('input[id="pass"]').fill(password || process.env.MAGENTO_CUSTOMER_PASS || 'Test1234!');
    await this.page.locator('button.action.login').click();
    await this.page.waitForLoadState('networkidle');
  }

  async loginAsAdmin(username?: string, password?: string): Promise<void> {
    await this.goto('/admin');
    await this.page.locator('input[name="login[username]"]').fill(username || process.env.MAGENTO_ADMIN_USER || 'admin');
    await this.page.locator('input[name="login[password]"]').fill(password || process.env.MAGENTO_ADMIN_PASS || 'admin123');
    await this.page.locator('.action-login').click();
    await this.page.waitForLoadState('networkidle');
    await this.dismissModals();
  }

  // ── Cart helpers ──────────────────────────────────────────────────────────
  async addProductToCart(productUrl: string, qty: number = 1): Promise<void> {
    await this.goto(productUrl);
    const qtyInput = this.page.locator('input[name="qty"]');
    if (await qtyInput.isVisible({ timeout: 3000 }).catch(() => false)) {
      await qtyInput.clear();
      await qtyInput.fill(qty.toString());
    }
    await this.page.locator('#product-addtocart-button').click();
    await this.page.waitForLoadState('networkidle');
    // Wait for success message
    await expect(
      this.page.locator('.message-success, [data-ui-id="message-success"]')
    ).toBeVisible({ timeout: 10000 });
  }

  async getCartItemCount(): Promise<number> {
    const counter = this.page.locator('.counter-number, .minicart-wrapper .counter');
    if (await counter.isVisible({ timeout: 3000 }).catch(() => false)) {
      const text = await counter.textContent();
      return parseInt(text?.trim() || '0', 10);
    }
    return 0;
  }

  async openMiniCart(): Promise<void> {
    await this.page.locator('[data-block="minicart"] .action.showcart').click();
    await expect(
      this.page.locator('[data-block="minicart"] [data-role="dropdownDialog"]')
    ).toBeVisible({ timeout: 5000 });
  }

  async emptyCart(): Promise<void> {
    await this.goto('/checkout/cart');
    const removeLinks = this.page.locator('.action.action-delete');
    const count = await removeLinks.count();
    for (let i = 0; i < count; i++) {
      await removeLinks.first().click();
      await this.page.waitForLoadState('networkidle');
    }
  }

  // ── Search helpers ────────────────────────────────────────────────────────
  async searchFor(query: string): Promise<void> {
    await this.page.locator('input[id="search"]').fill(query);
    await this.page.locator('button[title="Search"]').click();
    await this.page.waitForLoadState('networkidle');
  }

  // ── Price helpers ─────────────────────────────────────────────────────────
  getPrice(locator: string = '.price'): Locator {
    return this.page.locator(locator).first();
  }

  async getPriceValue(locator: string = '.price'): Promise<number> {
    const text = await this.page.locator(locator).first().textContent();
    return parseFloat(text?.replace(/[^0-9.]/g, '') || '0');
  }

  // ── Assertion helpers ─────────────────────────────────────────────────────
  async assertSuccessMessage(text?: string): Promise<void> {
    const msg = this.page.locator('.message-success, [data-ui-id="message-success"]');
    await expect(msg).toBeVisible({ timeout: 10000 });
    if (text) {
      await expect(msg).toContainText(text);
    }
  }

  async assertErrorMessage(text?: string): Promise<void> {
    const msg = this.page.locator('.message-error, .mage-error');
    await expect(msg).toBeVisible({ timeout: 5000 });
    if (text) {
      await expect(msg).toContainText(text);
    }
  }

  async takeScreenshot(name: string): Promise<void> {
    await this.page.screenshot({ path: `test-results/artifacts/${name}.png`, fullPage: true });
  }
}
