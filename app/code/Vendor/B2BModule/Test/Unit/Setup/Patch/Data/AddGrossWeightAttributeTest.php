<?php
declare(strict_types=1);

namespace Vendor\B2BModule\Test\Unit\Setup\Patch\Data;

use Magento\Eav\Setup\EavSetup;
use Magento\Eav\Setup\EavSetupFactory;
use Magento\Framework\Setup\ModuleDataSetupInterface;
use PHPUnit\Framework\TestCase;
use PHPUnit\Framework\MockObject\MockObject;
use Vendor\B2BModule\Setup\Patch\Data\AddGrossWeightAttribute;

/**
 * Unit test for AddGrossWeightAttribute data patch
 */
class AddGrossWeightAttributeTest extends TestCase
{
    /**
     * @var AddGrossWeightAttribute
     */
    private AddGrossWeightAttribute $patch;

    /**
     * @var ModuleDataSetupInterface|MockObject
     */
    private ModuleDataSetupInterface|MockObject $moduleDataSetup;

    /**
     * @var EavSetupFactory|MockObject
     */
    private EavSetupFactory|MockObject $eavSetupFactory;

    /**
     * @var EavSetup|MockObject
     */
    private EavSetup|MockObject $eavSetup;

    /**
     * @inheritdoc
     */
    protected function setUp(): void
    {
        $this->moduleDataSetup = $this->createMock(ModuleDataSetupInterface::class);
        $this->eavSetupFactory = $this->createMock(EavSetupFactory::class);
        $this->eavSetup = $this->createMock(EavSetup::class);

        $this->eavSetupFactory->method('create')
            ->willReturn($this->eavSetup);

        $this->patch = new AddGrossWeightAttribute(
            $this->moduleDataSetup,
            $this->eavSetupFactory
        );
    }

    /**
     * Test that apply method adds gross_weight attribute
     *
     * @return void
     */
    public function testApply(): void
    {
        $this->eavSetup->expects($this->once())
            ->method('addAttribute')
            ->with(
                \Magento\Catalog\Model\Product::ENTITY,
                'gross_weight',
                $this->callback(function ($config) {
                    return $config['type'] === 'decimal'
                        && $config['label'] === 'Gross Weight'
                        && $config['input'] === 'text'
                        && str_contains($config['apply_to'], 'simple')
                        && str_contains($config['apply_to'], 'configurable');
                })
            );

        $this->patch->apply();
    }

    /**
     * Test that revert method removes gross_weight attribute
     *
     * @return void
     */
    public function testRevert(): void
    {
        $this->eavSetup->expects($this->once())
            ->method('removeAttribute')
            ->with(
                \Magento\Catalog\Model\Product::ENTITY,
                'gross_weight'
            );

        $this->patch->revert();
    }

    /**
     * Test getDependencies returns empty array
     *
     * @return void
     */
    public function testGetDependencies(): void
    {
        $this->assertIsArray(AddGrossWeightAttribute::getDependencies());
        $this->assertEmpty(AddGrossWeightAttribute::getDependencies());
    }

    /**
     * Test getAliases returns empty array
     *
     * @return void
     */
    public function testGetAliases(): void
    {
        $this->assertIsArray($this->patch->getAliases());
        $this->assertEmpty($this->patch->getAliases());
    }
}