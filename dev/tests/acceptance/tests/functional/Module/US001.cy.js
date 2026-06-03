// cypress/e2e/catalog/product-attribute-warranty-period.cy.js

describe('Product Attribute: Warranty Period Creation', () => {
  const attributeCode = 'warranty_period';
  const attributeLabel = 'Warranty Period';
  const adminUsername = Cypress.env('ADMIN_USERNAME') || 'admin';
  const adminPassword = Cypress.env('ADMIN_PASSWORD') || 'admin123';
  const baseUrl = Cypress.env('ADMIN_URL') || '/admin';

  beforeEach(() => {
    // Login as catalog admin
    cy.adminLogin(adminUsername, adminPassword);
    
    // Intercept common API calls
    cy.intercept('POST', '**/admin/mui/index/render/**').as('muiRender');
    cy.intercept('POST', '**/admin/catalog/product_attribute/save/**').as('saveAttribute');
    cy.intercept('GET', '**/admin/catalog/product_attribute/edit/**').as('editAttribute');
    cy.intercept('POST', '**/admin/catalog/product_set/save/**').as('saveAttributeSet');
  });

  afterEach(() => {
    // Cleanup: Delete attribute if it exists
    cy.deleteProductAttributeIfExists(attributeCode);
  });

  describe('Attribute Creation Flow', () => {
    it('should create warranty_period attribute with correct configuration', () => {
      // Navigate to Stores > Attributes > Product
      cy.visit(`${baseUrl}/catalog/product_attribute`);
      cy.get('[data-ui-id="page-actions-toolbar-add-button"]', { timeout: 10000 })
        .should('be.visible')
        .click();

      // Wait for attribute form to load
      cy.get('#attribute_label', { timeout: 10000 }).should('be.visible');

      // Set Attribute Properties
      cy.get('#attribute_label')
        .clear()
        .type(attributeLabel);

      cy.get('#attribute_code')
        .clear()
        .type(attributeCode);

      // Set Catalog Input Type to 'Text Field'
      cy.get('#frontend_input')
        .select('text')
        .should('have.value', 'text');

      // Set Default Value (optional)
      cy.get('#default_value_text')
        .clear()
        .type('12 months');

      // Set Scope to 'Store View'
      cy.get('#is_global')
        .select('0') // 0 = Store View
        .should('have.value', '0');

      // Set Unique Value to 'No'
      cy.get('#is_unique')
        .select('0')
        .should('have.value', '0');

      // Expand Advanced Attribute Properties
      cy.get('[data-index="advanced_fieldset"]').click();
      cy.wait(500);

      // Set Attribute Code (if not auto-filled)
      cy.get('#attribute_code').then($input => {
        if ($input.val() === '') {
          cy.wrap($input).type(attributeCode);
        }
      });

      // Expand Storefront Properties
      cy.get('[data-index="front_fieldset"]').click();
      cy.wait(500);

      // Set 'Use in Layered Navigation' to 'Filterable (with results)'
      cy.get('#is_filterable')
        .select('1') // 1 = Filterable (with results)
        .should('have.value', '1');

      // Set 'Visible on Catalog Pages on Storefront' to 'Yes'
      cy.get('#is_visible_on_front')
        .select('1')
        .should('have.value', '1');

      // Set 'Used in Product Listing' to 'Yes'
      cy.get('#used_in_product_listing')
        .select('1')
        .should('have.value', '1');

      // Set 'Used for Sorting in Product Listing' to 'No'
      cy.get('#used_for_sort_by')
        .select('0')
        .should('have.value', '0');

      // Save the attribute
      cy.get('#save').click();
      cy.wait('@saveAttribute', { timeout: 15000 });

      // Verify success message
      cy.get('.message-success', { timeout: 10000 })
        .should('be.visible')
        .and('contain', 'You saved the product attribute');

      // Verify attribute appears in grid
      cy.visit(`${baseUrl}/catalog/product_attribute`);
      cy.get('#attributeGrid_filter_attribute_code')
        .clear()
        .type(attributeCode);
      cy.get('[data-ui-id="widget-button-3"]').click();
      cy.wait('@muiRender', { timeout: 10000 });

      cy.get('#attributeGrid')
        .should('contain', attributeCode)
        .and('contain', attributeLabel);
    });

    it('should add warranty_period attribute to Default attribute set', () => {
      // First create the attribute
      cy.createProductAttribute({
        code: attributeCode,
        label: attributeLabel,
        type: 'text',
        scope: '0',
        filterable: '1',
        visibleOnFront: '1'
      });

      // Navigate to Attribute Sets
      cy.visit(`${baseUrl}/catalog/product_set`);
      
      // Find and edit Default attribute set
      cy.get('#setGrid_filter_attribute_set_name')
        .clear()
        .type('Default');
      cy.get('[data-ui-id="widget-button-3"]').click();
      cy.wait(1000);

      cy.get('#setGrid tbody tr')
        .contains('Default')
        .parents('tr')
        .find('.action-menu-item')
        .first()
        .click();

      // Wait for attribute set edit page
      cy.get('#attribute-set-name', { timeout: 10000 }).should('be.visible');

      // Find warranty_period in unassigned attributes
      cy.get('#attribute-set-tree-container', { timeout: 10000 }).should('be.visible');
      
      // Search for the attribute in the tree
      cy.get('#attribute_set_form').within(() => {
        cy.contains(attributeLabel, { timeout: 10000 }).should('exist');
      });

      // Drag attribute to General group (or Product Details)
      cy.get('[data-tree-id="tree-div1"]').within(() => {
        cy.contains('General').should('be.visible');
      });

      // Use custom command to drag and drop attribute
      cy.dragAttributeToGroup(attributeLabel, 'General');

      // Save attribute set
      cy.get('#save').click();
      cy.wait('@saveAttributeSet', { timeout: 15000 });

      // Verify success message
      cy.get('.message-success', { timeout: 10000 })
        .should('be.visible')
        .and('contain', 'You saved the attribute set');

      // Verify attribute is in the set
      cy.reload();
      cy.get('[data-tree-id="tree-div1"]').within(() => {
        cy.contains('General').click();
        cy.contains(attributeLabel).should('be.visible');
      });
    });

    it('should validate required fields when creating attribute', () => {
      cy.visit(`${baseUrl}/catalog/product_attribute/new`);
      cy.get('#attribute_label', { timeout: 10000 }).should('be.visible');

      // Try to save without filling required fields
      cy.get('#save').click();

      // Verify validation messages
      cy.get('#attribute_label-error')
        .should('be.visible')
        .and('contain', 'This is a required field');

      cy.get('#frontend_input-error')
        .should('be.visible')
        .and('contain', 'This is a required field');
    });

    it('should prevent duplicate attribute code creation', () => {
      // Create first attribute
      cy.createProductAttribute({
        code: attributeCode,
        label: attributeLabel,
        type: 'text'
      });

      // Try to create duplicate
      cy.visit(`${baseUrl}/catalog/product_attribute/new`);
      cy.get('#attribute_label', { timeout: 10000 })
        .clear()
        .type('Duplicate Warranty');

      cy.get('#attribute_code')
        .clear()
        .type(attributeCode);

      cy.get('#frontend_input').select('text');

      cy.get('#save').click();

      // Verify error message
      cy.get('.message-error', { timeout: 10000 })
        .should('be.visible')
        .and('contain', 'Attribute with the same code');
    });
  });

  describe('Indexing and Cache Management', () => {
    beforeEach(() => {
      // Create attribute before indexing tests
      cy.createProductAttribute({
        code: attributeCode,
        label: attributeLabel,
        type: 'text',
        scope: '0',
        filterable: '1',
        visibleOnFront: '1'
      });
    });

    it('should reindex catalog_product_attribute successfully', () => {
      // Intercept CLI command execution (if using Cypress task)
      cy.task('execMagentoCommand', 'indexer:reindex catalog_product_attribute')
        .then((result) => {
          expect(result.code).to.equal(0);
          expect(result.stdout).to.contain('Catalog Product Attribute index has been rebuilt successfully');
        });
    });

    it('should flush cache successfully', () => {
      cy.task('execMagentoCommand', 'cache:flush')
        .then((result) => {
          expect(result.code).to.equal(0);
          expect(result.stdout).to.contain('Flushed cache types');
        });
    });

    it('should verify attribute is available after indexing via admin', () => {
      // Navigate to Cache Management
      cy.visit(`${baseUrl}/admin/cache`);
      
      // Select EAV cache types
      cy.get('[data-role="select-all"]').check();
      
      // Flush cache
      cy.get('#cache_grid_massaction-select').select('refresh');
      cy.get('[data-ui-id="form-button-submit"]').click();
      
      cy.get('.message-success', { timeout: 15000 })
        .should('be.visible')
        .and('contain', 'cache type(s) refreshed');

      // Navigate to Index Management
      cy.visit(`${baseUrl}/indexer/indexer/list`);
      
      // Find and reindex catalog_product_attribute
      cy.get('#indexer_grid_filter_title')
        .clear()
        .type('Product Attributes');
      cy.get('[data-ui-id="widget-button-3"]').click();
      cy.wait(1000);

      cy.get('#indexer_grid tbody tr')
        .contains('Product Attributes')
        .parents('tr')
        .find('input[type="checkbox"]')
        .check();

      cy.get('#indexer_grid_massaction-select').select('reindex');
      cy.get('[data-ui-id="form-button-submit"]').click();

      cy.get('.message-success', { timeout: 30000 })
        .should('be.visible')
        .and('contain', 'indexer(s) have been rebuilt');
    });
  });

  describe('Product Assignment and Storefront Display', () => {
    const testProductSku = `test-product-${Date.now()}`;
    const testProductName = 'Test Product with Warranty';
    const warrantyValue = '24 months';

    beforeEach(() => {
      // Create attribute and add to Default set
      cy.createProductAttribute({
        code: attributeCode,
        label: attributeLabel,
        type: 'text',
        scope: '0',
        filterable: '1',
        visibleOnFront: '1'
      });
      
      cy.addAttributeToSet(attributeCode, 'Default', 'General');
      
      // Reindex and flush cache
      cy.task('execMagentoCommand', 'indexer:reindex');
      cy.task('execMagentoCommand', 'cache:flush');
    });

    afterEach(() => {
      // Cleanup test product
      cy.deleteProductBySku(testProductSku);
    });

    it('should assign warranty_period value to a product', () => {
      // Create new product
      cy.visit(`${baseUrl}/catalog/product/new/set/4/type/simple`);
      cy.get('#product_form', { timeout: 15000 }).should('be.visible');

      // Fill basic product information
      cy.get('[name="product[name]"]').type(testProductName);
      cy.get('[name="product[sku]"]').type(testProductSku);
      cy.get('[name="product[price]"]').type('99.99');
      cy.get('[name="product[quantity_and_stock_status][qty]"]').type('100');

      // Enable product
      cy.get('[name="product[status]"]').select('1');

      // Scroll to warranty_period attribute
      cy.get(`[name="product[${attributeCode}]"]`, { timeout: 10000 })
        .scrollIntoView()
        .should('be.visible')
        .clear()
        .type(warrantyValue);

      // Save product
      cy.get('#save-button').click();
      cy.wait(3000);

      // Verify success message
      cy.get('.message-success', { timeout: 15000 })
        .should('be.visible')
        .and('contain', 'You saved the product');

      // Verify warranty value is saved
      cy.get(`[name="product[${attributeCode}]"]`)
        .should('have.value', warrantyValue);
    });

    it('should display warranty_period on product page storefront', () => {
      // Create product with warranty via API or admin
      cy.createSimpleProduct({
        sku: testProductSku,
        name: testProductName,
        price: 99.99,
        customAttributes: [
          {
            attribute_code: attributeCode,
            value: warrantyValue
          }
        ]
      });

      // Reindex and flush cache
      cy.task('execMagentoCommand', 'indexer:reindex');
      cy.task('execMagentoCommand', 'cache:flush');

      // Visit product page on storefront
      cy.visit(`/${testProductSku}.html`);
      
      // Verify warranty period is displayed
      cy.get('.product-info-main', { timeout: 10000 }).should('be.visible');
      
      cy.get('[data-th="Warranty Period"]', { timeout: 5000 })
        .should('be.visible')
        .and('contain', warrantyValue);

      // Alternative selector if using different theme
      cy.get('.product.attribute.warranty_period')
        .should('be.visible')
        .and('contain', warrantyValue);
    });

    it('should filter products by warranty_period in layered navigation', () => {
      // Create multiple products with different warranty values
      const products = [
        { sku: `${testProductSku}-1`, warranty: '12 months' },
        { sku: `${testProductSku}-2`, warranty: '24 months' },
        { sku: `${testProductSku}-3`, warranty: '36 months' }
      ];

      products.forEach((product, index) => {
        cy.createSimpleProduct({
          sku: product.sku,
          name: `${testProductName} ${index + 1}`,
          price: 99.99 + (index * 10),
          categoryIds: [2], // Default category
          customAttributes: [
            {
              attribute_code: attributeCode,
              value: product.warranty
            }
          ]
        });
      });

      // Reindex and flush cache
      cy.task('execMagentoCommand', 'indexer:reindex');
      cy.task('execMagentoCommand', 'cache:flush');

      // Visit