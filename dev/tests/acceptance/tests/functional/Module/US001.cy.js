// cypress/e2e/catalog/product-attribute-package-material.cy.js

describe('Product Attribute: Package Material - Creation and Configuration', () => {
  const attributeCode = 'package_material';
  const attributeLabel = 'Package Material';
  const attributeOptions = [
    { label: 'Cardboard', sortOrder: 1 },
    { label: 'Plastic', sortOrder: 2 },
    { label: 'Biodegradable', sortOrder: 3 },
    { label: 'Metal', sortOrder: 4 },
    { label: 'Glass', sortOrder: 5 },
    { label: 'Mixed Materials', sortOrder: 6 }
  ];

  beforeEach(() => {
    cy.loginAsAdmin('catalog_admin');
    cy.intercept('POST', '**/admin/catalog/product_attribute/save/**').as('saveAttribute');
    cy.intercept('GET', '**/admin/catalog/product_attribute/edit/**').as('editAttribute');
    cy.intercept('POST', '**/admin/indexer/indexer/massOnTheFly/**').as('reindexTrigger');
    cy.intercept('POST', '**/admin/cache/massRefresh/**').as('cacheRefresh');
  });

  afterEach(() => {
    // Cleanup: Delete test attribute if it exists
    cy.deleteProductAttributeIfExists(attributeCode);
  });

  describe('AC1: Create package_material attribute with basic configuration', () => {
    it('should create package_material attribute with dropdown input and layered navigation settings', () => {
      // Navigate to Stores > Attributes > Product
      cy.visit('/admin/catalog/product_attribute');
      cy.get('[data-test="page-title"]').should('contain', 'Product Attributes');

      // Click 'Add New Attribute'
      cy.get('[data-test="add-new-attribute-button"]').click();
      cy.url().should('include', '/admin/catalog/product_attribute/new');

      // Set attribute code
      cy.get('[data-test="attribute-code-input"]')
        .clear()
        .type(attributeCode);

      // Set frontend label
      cy.get('[data-test="frontend-label-input"]')
        .clear()
        .type(attributeLabel);

      // Set frontend input type to 'Dropdown'
      cy.get('[data-test="frontend-input-select"]')
        .select('select');
      cy.get('[data-test="frontend-input-select"]')
        .should('have.value', 'select');

      // Expand Storefront Properties section
      cy.get('[data-test="storefront-properties-section"]').click();

      // Set 'Use in Layered Navigation' to 'Filterable (with results)'
      cy.get('[data-test="layered-navigation-select"]')
        .select('1'); // 1 = Filterable (with results)
      cy.get('[data-test="layered-navigation-select"]')
        .should('have.value', '1');

      // Set 'Visible on Catalog Pages on Storefront' to 'Yes'
      cy.get('[data-test="visible-on-catalog-pages-select"]')
        .select('1');
      cy.get('[data-test="visible-on-catalog-pages-select"]')
        .should('have.value', '1');

      // Set 'Used in Product Listing' to 'Yes'
      cy.get('[data-test="used-in-product-listing-select"]')
        .select('1');
      cy.get('[data-test="used-in-product-listing-select"]')
        .should('have.value', '1');

      // Expand Attribute Set Assignment section
      cy.get('[data-test="attribute-set-section"]').click();

      // Add attribute to 'Default' attribute set
      cy.get('[data-test="attribute-set-list"]')
        .contains('Default')
        .parent()
        .find('[data-test="attribute-set-checkbox"]')
        .check();

      // Save attribute
      cy.get('[data-test="save-attribute-button"]').click();

      // Wait for save operation
      cy.wait('@saveAttribute').its('response.statusCode').should('eq', 200);

      // Verify success message
      cy.get('[data-test="message-success"]')
        .should('be.visible')
        .and('contain', 'You saved the product attribute');

      // Verify attribute appears in grid
      cy.visit('/admin/catalog/product_attribute');
      cy.get('[data-test="attribute-grid"]')
        .contains(attributeCode)
        .should('be.visible');

      // Verify attribute appears in product edit form
      cy.createSimpleProduct('test-product-for-attribute');
      cy.visit('/admin/catalog/product/edit/id/');
      cy.get('[data-test="product-form"]')
        .contains(attributeLabel)
        .should('be.visible');
    });
  });

  describe('AC2: Configure attribute options with sort order', () => {
    beforeEach(() => {
      // Create base attribute first
      cy.createProductAttribute({
        code: attributeCode,
        label: attributeLabel,
        inputType: 'select'
      });
    });

    it('should add multiple options with correct sort order', () => {
      // Navigate to edit attribute
      cy.visit('/admin/catalog/product_attribute');
      cy.get('[data-test="attribute-grid"]')
        .contains(attributeCode)
        .click();

      cy.wait('@editAttribute');

      // Expand Manage Options section
      cy.get('[data-test="manage-options-section"]').click();

      // Add each option
      attributeOptions.forEach((option, index) => {
        cy.get('[data-test="add-option-button"]').click();

        cy.get(`[data-test="option-row-${index}"]`).within(() => {
          // Set admin label
          cy.get('[data-test="option-admin-label"]')
            .clear()
            .type(option.label);

          // Set default store view label
          cy.get('[data-test="option-default-label"]')
            .clear()
            .type(option.label);

          // Set sort order
          cy.get('[data-test="option-sort-order"]')
            .clear()
            .type(option.sortOrder.toString());
        });
      });

      // Save attribute
      cy.get('[data-test="save-attribute-button"]').click();
      cy.wait('@saveAttribute').its('response.statusCode').should('eq', 200);

      // Verify success message
      cy.get('[data-test="message-success"]')
        .should('be.visible')
        .and('contain', 'You saved the product attribute');

      // Verify options are saved in correct order in admin
      cy.reload();
      cy.wait('@editAttribute');
      cy.get('[data-test="manage-options-section"]').click();

      attributeOptions.forEach((option, index) => {
        cy.get(`[data-test="option-row-${index}"]`).within(() => {
          cy.get('[data-test="option-admin-label"]')
            .should('have.value', option.label);
          cy.get('[data-test="option-sort-order"]')
            .should('have.value', option.sortOrder.toString());
        });
      });

      // Verify options appear in correct order on frontend
      cy.logoutAdmin();
      cy.visit('/');
      cy.get('[data-test="category-nav"]').first().click();

      // Check layered navigation
      cy.get('[data-test="layered-nav-filter"]')
        .contains(attributeLabel)
        .should('be.visible')
        .click();

      // Verify options order in filter
      attributeOptions.forEach((option, index) => {
        cy.get('[data-test="filter-option"]')
          .eq(index)
          .should('contain', option.label);
      });
    });

    it('should handle option deletion and reordering', () => {
      // Add options first
      cy.visit('/admin/catalog/product_attribute');
      cy.get('[data-test="attribute-grid"]').contains(attributeCode).click();
      cy.wait('@editAttribute');
      cy.get('[data-test="manage-options-section"]').click();

      // Add 3 options
      for (let i = 0; i < 3; i++) {
        cy.get('[data-test="add-option-button"]').click();
        cy.get(`[data-test="option-row-${i}"]`).within(() => {
          cy.get('[data-test="option-admin-label"]')
            .type(attributeOptions[i].label);
        });
      }

      cy.get('[data-test="save-attribute-button"]').click();
      cy.wait('@saveAttribute');

      // Delete middle option
      cy.reload();
      cy.wait('@editAttribute');
      cy.get('[data-test="manage-options-section"]').click();
      cy.get('[data-test="option-row-1"]')
        .find('[data-test="delete-option-button"]')
        .click();

      cy.get('[data-test="save-attribute-button"]').click();
      cy.wait('@saveAttribute');

      // Verify only 2 options remain
      cy.reload();
      cy.wait('@editAttribute');
      cy.get('[data-test="manage-options-section"]').click();
      cy.get('[data-test="option-row"]').should('have.length', 2);
    });
  });

  describe('AC3: Configure advanced attribute settings', () => {
    beforeEach(() => {
      cy.createProductAttribute({
        code: attributeCode,
        label: attributeLabel,
        inputType: 'select',
        options: attributeOptions
      });
    });

    it('should enable promo rules, search, and comparison features', () => {
      // Navigate to edit attribute
      cy.visit('/admin/catalog/product_attribute');
      cy.get('[data-test="attribute-grid"]').contains(attributeCode).click();
      cy.wait('@editAttribute');

      // Expand Advanced Attribute Properties
      cy.get('[data-test="advanced-properties-section"]').click();

      // Set 'Used for Promo Rule Conditions' to 'Yes'
      cy.get('[data-test="promo-rule-conditions-select"]')
        .select('1');
      cy.get('[data-test="promo-rule-conditions-select"]')
        .should('have.value', '1');

      // Set 'Used in Search' to 'Yes'
      cy.get('[data-test="used-in-search-select"]')
        .select('1');
      cy.get('[data-test="used-in-search-select"]')
        .should('have.value', '1');

      // Set 'Comparable on Storefront' to 'Yes'
      cy.get('[data-test="comparable-on-storefront-select"]')
        .select('1');
      cy.get('[data-test="comparable-on-storefront-select"]')
        .should('have.value', '1');

      // Save attribute configuration
      cy.get('[data-test="save-attribute-button"]').click();
      cy.wait('@saveAttribute').its('response.statusCode').should('eq', 200);

      cy.get('[data-test="message-success"]')
        .should('be.visible')
        .and('contain', 'You saved the product attribute');

      // Verify attribute is available in catalog price rules
      cy.visit('/admin/catalog_rule/promo_catalog/new');
      cy.get('[data-test="conditions-section"]').click();
      cy.get('[data-test="add-condition-button"]').click();
      cy.get('[data-test="condition-attribute-select"]')
        .select(attributeCode);
      cy.get('[data-test="condition-attribute-select"]')
        .should('have.value', attributeCode);

      // Verify attribute is searchable via quick search
      cy.logoutAdmin();
      cy.visit('/');
      
      // Create test product with package_material attribute
      cy.loginAsAdmin('catalog_admin');
      cy.createSimpleProduct('searchable-product', {
        [attributeCode]: 'Biodegradable'
      });
      cy.logoutAdmin();

      // Wait for indexing
      cy.wait(5000);

      cy.visit('/');
      cy.get('[data-test="search-input"]')
        .type('Biodegradable{enter}');
      cy.get('[data-test="search-results"]')
        .should('contain', 'searchable-product');

      // Verify attribute appears in advanced search
      cy.visit('/catalogsearch/advanced');
      cy.get('[data-test="advanced-search-form"]')
        .contains(attributeLabel)
        .should('be.visible');
      cy.get(`[data-test="advanced-search-${attributeCode}"]`)
        .should('exist');

      // Verify attribute appears in product comparison
      cy.visit('/');
      cy.addProductToCompare('searchable-product');
      cy.get('[data-test="compare-products-link"]').click();
      cy.get('[data-test="comparison-table"]')
        .contains(attributeLabel)
        .should('be.visible');
    });

    it('should validate attribute in B2B catalog price rules', () => {
      cy.visit('/admin/catalog_rule/promo_catalog/new');
      
      // Set rule name
      cy.get('[data-test="rule-name-input"]')
        .type('Package Material Discount Rule');

      // Add condition using package_material
      cy.get('[data-test="conditions-section"]').click();
      cy.get('[data-test="add-condition-button"]').click();
      cy.get('[data-test="condition-attribute-select"]')
        .select(attributeCode);

      // Set condition value
      cy.get('[data-test="condition-operator-select"]')
        .select('is');
      cy.get('[data-test="condition-value-select"]')
        .select('Biodegradable');

      // Set discount
      cy.get('[data-test="discount-amount-input"]')
        .type('10');

      // Save rule
      cy.get('[data-test="save-rule-button"]').click();
      cy.get('[data-test="message-success"]')
        .should('contain', 'You saved the rule');
    });
  });

  describe('AC4: Verify indexers and cache invalidation', () => {
    beforeEach(() => {
      cy.intercept('GET', '**/admin/indexer/indexer/list/**').as('indexerList');
      cy.intercept('POST', '**/admin/cache/massRefresh/**').as('cacheRefresh');
    });

    it('should trigger required indexers after attribute creation', () => {
      const requiredIndexers = [
        'catalog_product_attribute',
        'catalog_product_flat',
        'catalogsearch_fulltext',
        'catalog_category_product'
      ];

      // Create attribute
      cy.visit('/admin/catalog/product_attribute/new');
      
      cy.get('[data-test="attribute-code-input"]').type(attributeCode);
      cy.get('[data-test="frontend-label-input"]').type(attributeLabel);
      cy.get('[data-test="frontend-input-select"]').select('select');
      
      // Monitor indexer status before save
      cy.visit('/admin/indexer/indexer/list');
      cy.wait('@indexerList');

      // Save attribute
      cy.visit('/admin/catalog/product_attribute/new');
      cy.get('[data-test="attribute-code-input"]').type(attributeCode);
      cy.get('[data-test="frontend-label-input"]').type(attributeLabel);
      cy.get('[data-test="frontend-input-select"]').select('select');
      cy.get('[data-test="save-attribute-button"]').click();
      cy.wait('@saveAttribute');

      // Check indexer status
      cy.visit('/admin/indexer/indexer/list');
      cy.wait('@indexerList');

      requiredIndex