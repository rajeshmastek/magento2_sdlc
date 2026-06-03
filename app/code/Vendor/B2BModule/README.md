# Vendor_B2BModule

## Overview
This module adds custom product attributes to Adobe Commerce 2.4.9 for B2B functionality.

## Features

### Warranty Period Attribute
- Store-scoped text field for warranty information
- Filterable in layered navigation
- Visible on product pages and listings
- Searchable and comparable

### Package Material Attribute
- Global-scoped dropdown with predefined options:
  - Cardboard
  - Plastic
  - Biodegradable
  - Metal
  - Glass
  - Mixed Materials
- Filterable in layered navigation (with results count)
- Visible on catalog pages
- Searchable and comparable
- Used in promotional rules
- Added to Default attribute set

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
2. Find `warranty_period` and `package_material` attributes
3. Edit products and set values

### Storefront Display
Both attributes are displayed on:
- Product detail pages (via custom template)
- Product listings (if configured)
- Layered navigation filters
- Product comparison
- Search results

### Promotional Rules
The `package_material` attribute can be used in:
- Catalog Price Rules
- Cart Price Rules
- Related Products Rules

## Technical Details

### Warranty Period
- **Attribute Code**: `warranty_period`
- **Type**: varchar (text field)
- **Scope**: Store View
- **Filterable**: Yes (with results)

### Package Material
- **Attribute Code**: `package_material`
- **Type**: int (dropdown/select)
- **Scope**: Global
- **Filterable**: Yes (with results)
- **Used in Promo Rules**: Yes
- **Source Model**: Table-based options

## Uninstallation

Both patches implement `PatchRevertableInterface`:

```bash
bin/magento module:uninstall Vendor_B2BModule
```

## Compatibility
- Adobe Commerce 2.4.9
- PHP 8.1, 8.2, 8.3

## License
Proprietary