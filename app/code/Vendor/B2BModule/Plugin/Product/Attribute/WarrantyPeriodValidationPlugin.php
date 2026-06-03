<?php
declare(strict_types=1);
/**
 * Copyright © Vendor. All rights reserved.
 * See COPYING.txt for license details.
 */

namespace Vendor\B2BModule\Plugin\Product\Attribute;

use Magento\Catalog\Model\Product;
use Magento\Framework\Exception\LocalizedException;

/**
 * Plugin to validate warranty_period attribute value format
 */
class WarrantyPeriodValidationPlugin
{
    /**
     * Validate warranty period format before product save
     *
     * @param Product $subject
     * @return void
     * @throws LocalizedException
     */
    public function beforeBeforeSave(Product $subject): void
    {
        $warrantyPeriod = $subject->getData('warranty_period');
        
        if ($warrantyPeriod !== null && $warrantyPeriod !== '') {
            // Optional: Add custom validation logic here
            // Example: validate format like "12 months" or "2 years"
            $warrantyPeriod = trim((string)$warrantyPeriod);
            
            if (strlen($warrantyPeriod) > 255) {
                throw new LocalizedException(
                    __('Warranty Period must not exceed 255 characters.')
                );
            }
            
            $subject->setData('warranty_period', $warrantyPeriod);
        }
    }
}