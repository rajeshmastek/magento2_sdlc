<?php
declare(strict_types=1);

namespace Vendor\Module\Test\Unit\Observer;

use PHPUnit\Framework\TestCase;
use PHPUnit\Framework\MockObject\MockObject;
use Vendor\Module\Observer\ModuleObserver;
use Magento\Eav\Setup\EavSetup;
use Magento\Framework\Event\Observer;
use Magento\Framework\Event;

class ModuleObserverTest extends TestCase
{
    private ModuleObserver $subject;
    private MockObject $eavSetupMock;
    private MockObject $observerMock;
    private MockObject $eventMock;

    protected function setUp(): void
    {
        $this->eavSetupMock = $this->createMock(EavSetup::class);
        $this->observerMock = $this->createMock(Observer::class);
        $this->eventMock = $this->createMock(Event::class);
        $this->subject = new ModuleObserver($this->eavSetupMock);
    }

    public function testExecute_createsPackageMaterialAttribute_withCorrectConfiguration(): void
    {
        $expectedConfig = [
            'type' => 'int',
            'label' => 'Package Material',
            'input' => 'select',
            'required' => false,
            'visible_on_front' => true,
            'used_in_product_listing' => true,
            'is_filterable' => 1,
            'is_filterable_in_search' => true,
            'user_defined' => true,
            'searchable' => false,
            'comparable' => false
        ];

        $this->eavSetupMock->expects($this->once())
            ->method('addAttribute')
            ->with(
                \Magento\Catalog\Model\Product::ENTITY,
                'package_material',
                $this->callback(function ($config) use ($expectedConfig) {
                    return $config['input'] === 'select' 
                        && $config['visible_on_front'] === true
                        && $config['used_in_product_listing'] === true
                        && $config['is_filterable'] === 1;
                })
            );

        $this->observerMock->method('getEvent')->willReturn($this->eventMock);
        $this->subject->execute($this->observerMock);
    }

    public function testExecute_addsAttributeToDefaultAttributeSet_successfully(): void
    {
        $attributeSetId = 4;
        $attributeGroupId = 7;

        $this->eavSetupMock->expects($this->once())
            ->method('addAttribute')
            ->willReturn(true);

        $this->eavSetupMock->expects($this->once())
            ->method('addAttributeToSet')
            ->with(
                \Magento\Catalog\Model\Product::ENTITY,
                'Default',
                $this->anything(),
                'package_material'
            );

        $this->observerMock->method('getEvent')->willReturn($this->eventMock);
        $this->subject->execute($this->observerMock);
    }

    public function testExecute_attributeAppearsInProductEditForm_afterCreation(): void
    {
        $this->eavSetupMock->expects($this->once())
            ->method('addAttribute')
            ->with(
                \Magento\Catalog\Model\Product::ENTITY,
                'package_material',
                $this->callback(function ($config) {
                    return isset($config['visible']) && $config['visible'] === true
                        && isset($config['user_defined']) && $config['user_defined'] === true;
                })
            )
            ->willReturn(true);

        $this->observerMock->method('getEvent')->willReturn($this->eventMock);
        $result = $this->subject->execute($this->observerMock);
        $this->assertNull($result);
    }
}