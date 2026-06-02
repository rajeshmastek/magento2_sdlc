# Vendor_B2BModule - Gross Weight Attribute

## Overview
This module adds a `gross_weight` product attribute to Adobe Commerce that accepts decimal values and is available for all product types.

## Features
- Decimal attribute for storing gross weight (product + packaging)
- Available for all product types: simple, configurable, virtual, bundle, downloadable, grouped
- Global scope attribute
- Visible in admin grid and product edit form
- Frontend display on product detail page
- Admin configuration to show/hide on frontend
- Comparable attribute for product comparison
- Validation for positive numbers only

## Installation
```bash
bin/magento module:enable Vendor_B2BModule
bin/magento setup:upgrade
bin/magento setup:di:compile
bin/magento cache:flush
```

## Usage
1. Navigate to Catalog > Products in admin
2. Edit any product
3. Find "Gross Weight" field in Product Details section
4. Enter weight value in kilograms (decimal allowed)
5. Save product

## Configuration
Stores > Configuration > Catalog > Catalog > Frontend > Show Gross Weight on Product Page

## Technical Details
- Attribute code: `gross_weight`
- Type: decimal
- Backend model: Magento\Catalog\Model\Product\Attribute\Backend\Weight
- Frontend validation: validate-number validate-zero-or-greater
- Default unit: kg

## Testing
```bash
bin/magento dev:tests:run unit -- vendor/vendor/module-b2bmodule/Test/Unit