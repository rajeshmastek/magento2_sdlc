<?php
declare(strict_types=1);
/**
 * Copyright © Vendor. All rights reserved.
 * See COPYING.txt for license details.
 */

namespace Vendor\B2BModule\Plugin\Product\Attribute;

use Magento\Catalog\Model\Product;
use Magento\Framework\Exception\LocalizedException;
use Magento\Eav\Model\Config as EavConfig;

/**
 * Plugin to validate package_material attribute value
 */
class PackageMaterialValidationPlugin
{
    /**
     * @var EavConfig
     */
    private EavConfig $eavConfig;

    /**
     * @param EavConfig $eavConfig
     */
    public function __construct(EavConfig $eavConfig)
    {
        $this->eavConfig = $eavConfig;
    }

    /**
     * Validate package material option before product save
     *
     * @param Product $subject
     * @return void
     * @throws LocalizedException
     */
    public function beforeBeforeSave(Product $subject): void
    {
        $packageMaterial = $subject->getData('package_material');
        
        if ($packageMaterial !== null && $packageMaterial !== '') {
            $attribute = $this->eavConfig->getAttribute(Product::ENTITY, 'package_material');
            $options = $attribute->getSource()->getAllOptions(false);
            
            $validOptionIds = array_column($options, 'value');
            
            if (!in_array($packageMaterial, $validOptionIds, true)) {
                throw new LocalizedException(
                    __('Invalid Package Material option selected.')
                );
            }
        }
    }
}