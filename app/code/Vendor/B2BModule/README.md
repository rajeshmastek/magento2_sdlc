# Vendor_B2BModule

## Overview
This module adds a `warranty_period` product attribute to Adobe Commerce 2.4.9.

## Features
- Creates a store-scoped text field attribute for warranty information
- Attribute is filterable in layered navigation
- Visible on product pages and in product listings
- Added to the Default attribute set automatically
- Searchable and comparable

## Installation

1. Copy module to `app/code/Vendor/B2BModule`
2. Run setup commands:

```bash
bin/magento module:enable Vendor_B2BModule
bin/magento setup:upgrade
bin/magento setup:di:compile
bin/magento setup:static-content:deploy -f
bin/magento indexer:reindex catalog_product_attribute
bin/magento cache:flush
```

## Usage

### Admin Configuration
1. Navigate to **Stores > Attributes > Product**
2. Find the `warranty_period` attribute
3. Edit products and set warranty period values (e.g., "12 months", "2 years")

### Storefront Display
The warranty period will be displayed on:
- Product detail pages
- Product listings (if configured)
- Layered navigation filters
- Product comparison

## Technical Details

- **Attribute Code**: `warranty_period`
- **Type**: varchar (text field)
- **Scope**: Store View
- **Filterable**: Yes (with results)
- **Searchable**: Yes
- **Visible on Front**: Yes
- **Used in Listing**: Yes

## Uninstallation

The patch implements `PatchRevertableInterface`, allowing clean removal:

```bash
bin/magento module:uninstall Vendor_B2BModule
```

## Compatibility
- Adobe Commerce 2.4.9
- PHP 8.1, 8.2, 8.3

## License
Proprietary