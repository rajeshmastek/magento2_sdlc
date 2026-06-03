<?php
declare(strict_types=1);

namespace Vendor\WarrantyAttribute\Test\Unit\Model;

use Magento\Catalog\Model\Product;
use Magento\Catalog\Model\ResourceModel\Eav\Attribute;
use Magento\Eav\Api\AttributeRepositoryInterface;
use Magento\Eav\Api\Data\AttributeInterface;
use Magento\Eav\Model\Entity\Attribute\Set;
use Magento\Eav\Model\Entity\Attribute\SetFactory;
use Magento\Eav\Setup\EavSetup;
use Magento\Eav\Setup\EavSetupFactory;
use Magento\Framework\Exception\LocalizedException;
use Magento\Framework\Exception\NoSuchEntityException;
use Magento\Framework\Setup\ModuleDataSetupInterface;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use Psr\Log\LoggerInterface;
use Vendor\WarrantyAttribute\Model\WarrantyAttributeCreator;

class WarrantyAttributeCreatorTest extends TestCase
{
    private WarrantyAttributeCreator $warrantyAttributeCreator;
    private EavSetupFactory|MockObject $eavSetupFactoryMock;
    private EavSetup|MockObject $eavSetupMock;
    private AttributeRepositoryInterface|MockObject $attributeRepositoryMock;
    private SetFactory|MockObject $attributeSetFactoryMock;
    private LoggerInterface|MockObject $loggerMock;
    private ModuleDataSetupInterface|MockObject $setupMock;

    protected function setUp(): void
    {
        $this->eavSetupFactoryMock = $this->createMock(EavSetupFactory::class);
        $this->eavSetupMock = $this->createMock(EavSetup::class);
        $this->attributeRepositoryMock = $this->createMock(AttributeRepositoryInterface::class);
        $this->attributeSetFactoryMock = $this->createMock(SetFactory::class);
        $this->loggerMock = $this->createMock(LoggerInterface::class);
        $this->setupMock = $this->createMock(ModuleDataSetupInterface::class);

        $this->eavSetupFactoryMock
            ->method('create')
            ->willReturn($this->eavSetupMock);

        $this->warrantyAttributeCreator = new WarrantyAttributeCreator(
            $this->eavSetupFactoryMock,
            $this->attributeRepositoryMock,
            $this->attributeSetFactoryMock,
            $this->loggerMock
        );
    }

    public function testCreateWarrantyAttribute_givenValidConfiguration_expectAttributeCreatedSuccessfully(): void
    {
        $attributeCode = 'warranty_period';
        $defaultAttributeSetId = 4;

        $this->eavSetupMock
            ->expects($this->once())
            ->method('addAttribute')
            ->with(
                Product::ENTITY,
                $attributeCode,
                $this->callback(function ($config) {
                    return $config['type'] === 'varchar'
                        && $config['input'] === 'text'
                        && $config['label'] === 'Warranty Period'
                        && $config['global'] === \Magento\Eav\Model\Entity\Attribute\ScopedAttributeInterface::SCOPE_STORE
                        && $config['visible'] === true
                        && $config['required'] === false
                        && $config['user_defined'] === true
                        && $config['searchable'] === false
                        && $config['filterable'] === 2
                        && $config['comparable'] === false
                        && $config['visible_on_front'] === true
                        && $config['used_in_product_listing'] === true
                        && $config['unique'] === false;
                })
            );

        $this->eavSetupMock
            ->expects($this->once())
            ->method('getAttributeId')
            ->with(Product::ENTITY, $attributeCode)
            ->willReturn(123);

        $this->eavSetupMock
            ->expects($this->once())
            ->method('getDefaultAttributeSetId')
            ->with(Product::ENTITY)
            ->willReturn($defaultAttributeSetId);

        $this->eavSetupMock
            ->expects($this->once())
            ->method('getDefaultAttributeGroupId')
            ->with(Product::ENTITY, $defaultAttributeSetId)
            ->willReturn(7);

        $this->eavSetupMock
            ->expects($this->once())
            ->method('addAttributeToSet')
            ->with(Product::ENTITY, $defaultAttributeSetId, 7, $attributeCode);

        $result = $this->warrantyAttributeCreator->create($this->setupMock);

        $this->assertTrue($result);
    }

    public function testCreateWarrantyAttribute_givenAttributeAlreadyExists_expectNoExceptionAndReturnTrue(): void
    {
        $attributeCode = 'warranty_period';

        $attributeMock = $this->createMock(AttributeInterface::class);
        $attributeMock->method('getAttributeId')->willReturn(123);

        $this->attributeRepositoryMock
            ->expects($this->once())
            ->method('get')
            ->with(Product::ENTITY, $attributeCode)
            ->willReturn($attributeMock);

        $this->eavSetupMock
            ->expects($this->never())
            ->method('addAttribute');

        $this->loggerMock
            ->expects($this->once())
            ->method('info')
            ->with($this->stringContains('already exists'));

        $result = $this->warrantyAttributeCreator->create($this->setupMock);

        $this->assertTrue($result);
    }

    public function testCreateWarrantyAttribute_givenAttributeNotExists_expectAttributeCreated(): void
    {
        $attributeCode = 'warranty_period';

        $this->attributeRepositoryMock
            ->expects($this->once())
            ->method('get')
            ->with(Product::ENTITY, $attributeCode)
            ->willThrowException(new NoSuchEntityException(__('Attribute not found')));

        $this->eavSetupMock
            ->expects($this->once())
            ->method('addAttribute')
            ->with(Product::ENTITY, $attributeCode, $this->isType('array'));

        $this->eavSetupMock
            ->method('getAttributeId')
            ->willReturn(123);

        $this->eavSetupMock
            ->method('getDefaultAttributeSetId')
            ->willReturn(4);

        $this->eavSetupMock
            ->method('getDefaultAttributeGroupId')
            ->willReturn(7);

        $result = $this->warrantyAttributeCreator->create($this->setupMock);

        $this->assertTrue($result);
    }

    public function testCreateWarrantyAttribute_givenExceptionDuringCreation_expectFalseReturned(): void
    {
        $attributeCode = 'warranty_period';
        $exceptionMessage = 'Database connection error';

        $this->attributeRepositoryMock
            ->method('get')
            ->willThrowException(new NoSuchEntityException(__('Attribute not found')));

        $this->eavSetupMock
            ->expects($this->once())
            ->method('addAttribute')
            ->willThrowException(new LocalizedException(__($exceptionMessage)));

        $this->loggerMock
            ->expects($this->once())
            ->method('error')
            ->with($this->stringContains($exceptionMessage));

        $result = $this->warrantyAttributeCreator->create($this->setupMock);

        $this->assertFalse($result);
    }

    public function testAddAttributeToDefaultSet_givenValidAttributeSetId_expectAttributeAddedSuccessfully(): void
    {
        $attributeCode = 'warranty_period';
        $attributeSetId = 4;
        $attributeGroupId = 7;

        $this->eavSetupMock
            ->expects($this->once())
            ->method('getDefaultAttributeSetId')
            ->with(Product::ENTITY)
            ->willReturn($attributeSetId);

        $this->eavSetupMock
            ->expects($this->once())
            ->method('getDefaultAttributeGroupId')
            ->with(Product::ENTITY, $attributeSetId)
            ->willReturn($attributeGroupId);

        $this->eavSetupMock
            ->expects($this->once())
            ->method('addAttributeToSet')
            ->with(Product::ENTITY, $attributeSetId, $attributeGroupId, $attributeCode);

        $this->warrantyAttributeCreator->addToAttributeSet(
            $this->setupMock,
            $attributeCode,
            $attributeSetId
        );
    }

    public function testAddAttributeToDefaultSet_givenNullAttributeSetId_expectDefaultSetUsed(): void
    {
        $attributeCode = 'warranty_period';
        $defaultAttributeSetId = 4;
        $attributeGroupId = 7;

        $this->eavSetupMock
            ->expects($this->once())
            ->method('getDefaultAttributeSetId')
            ->with(Product::ENTITY)
            ->willReturn($defaultAttributeSetId);

        $this->eavSetupMock
            ->expects($this->once())
            ->method('getDefaultAttributeGroupId')
            ->with(Product::ENTITY, $defaultAttributeSetId)
            ->willReturn($attributeGroupId);

        $this->eavSetupMock
            ->expects($this->once())
            ->method('addAttributeToSet')
            ->with(Product::ENTITY, $defaultAttributeSetId, $attributeGroupId, $attributeCode);

        $this->warrantyAttributeCreator->addToAttributeSet(
            $this->setupMock,
            $attributeCode,
            null
        );
    }

    public function testAddAttributeToDefaultSet_givenInvalidAttributeSetId_expectExceptionThrown(): void
    {
        $attributeCode = 'warranty_period';
        $invalidAttributeSetId = 999;

        $this->eavSetupMock
            ->expects($this->once())
            ->method('getDefaultAttributeGroupId')
            ->with(Product::ENTITY, $invalidAttributeSetId)
            ->willThrowException(new LocalizedException(__('Attribute set not found')));

        $this->expectException(LocalizedException::class);
        $this->expectExceptionMessage('Attribute set not found');

        $this->warrantyAttributeCreator->addToAttributeSet(
            $this->setupMock,
            $attributeCode,
            $invalidAttributeSetId
        );
    }

    #[DataProvider('attributeConfigurationDataProvider')]
    public function testCreateWarrantyAttribute_givenDifferentConfigurations_expectCorrectAttributeCreated(
        array $config,
        bool $expectedResult
    ): void {
        $this->attributeRepositoryMock
            ->method('get')
            ->willThrowException(new NoSuchEntityException(__('Attribute not found')));

        if ($expectedResult) {
            $this->eavSetupMock
                ->expects($this->once())
                ->method('addAttribute')
                ->with(Product::ENTITY, $config['code'], $this->isType('array'));

            $this->eavSetupMock
                ->method('getAttributeId')
                ->willReturn(123);

            $this->eavSetupMock
                ->method('getDefaultAttributeSetId')
                ->willReturn(4);

            $this->eavSetupMock
                ->method('getDefaultAttributeGroupId')
                ->willReturn(7);
        } else {
            $this->eavSetupMock
                ->method('addAttribute')
                ->willThrowException(new LocalizedException(__('Invalid configuration')));
        }

        $result = $this->warrantyAttributeCreator->create($this->setupMock, $config);

        $this->assertEquals($expectedResult, $result);
    }

    public static function attributeConfigurationDataProvider(): array
    {
        return [
            'valid_text_field_configuration' => [
                [
                    'code' => 'warranty_period',
                    'type' => 'varchar',
                    'input' => 'text',
                    'label' => 'Warranty Period',
                    'global' => \Magento\Eav\Model\Entity\Attribute\ScopedAttributeInterface::SCOPE_STORE,
                    'filterable' => 2,
                    'visible_on_front' => true,
                ],
                true,
            ],
            'valid_dropdown_configuration' => [
                [
                    'code' => 'warranty_type',
                    'type' => 'int',
                    'input' => 'select',
                    'label' => 'Warranty Type',
                    'global' => \Magento\Eav\Model\Entity\Attribute\ScopedAttributeInterface::SCOPE_GLOBAL,
                    'filterable' => 1,
                    'visible_on_front' => true,
                ],
                true,
            ],
            'valid_multiselect_configuration' => [
                [
                    'code' => 'warranty_coverage',
                    'type' => 'varchar',
                    'input' => 'multiselect',
                    'label' => 'Warranty Coverage',
                    'global' => \Magento\Eav\Model\Entity\Attribute\ScopedAttributeInterface::SCOPE_WEBSITE,
                    'filterable' => 2,
                    'visible_on_front' => false,
                ],
                true,
            ],
        ];
    }

    #[DataProvider('attributeScopeDataProvider')]
    public function testCreateWarrantyAttribute_givenDifferentScopes_expectCorrectScopeSet(
        int $scope,
        string $scopeName
    ): void {
        $attributeCode = 'warranty_period';

        $this->attributeRepositoryMock
            ->method('get')
            ->willThrowException(new NoSuchEntityException(__('Attribute not found')));

        $this->eavSetupMock
            ->expects($this->once())
            ->method('addAttribute')
            ->with(
                Product::ENTITY,
                $attributeCode,
                $this->callback(function ($config) use ($scope) {
                    return $config['global'] === $scope;
                })
            );

        $this->eavSetupMock
            ->method('getAttributeId')
            ->willReturn(123);

        $this->eavSetupMock
            ->method('getDefaultAttributeSetId')
            ->willReturn(4);

        $this->eavSetupMock
            ->method('getDefaultAttributeGroupId')
            ->willReturn(7);

        $config = ['scope' => $scope];
        $result = $this->warrantyAttributeCreator->create($this->setupMock, $config);

        $this->assertTrue($result);
    }

    public static function attributeScopeDataProvider(): array
    {
        return [
            'global_scope' => [
                \Magento\Eav\Model\Entity\Attribute\ScopedAttributeInterface::SCOPE_GLOBAL,
                'Global',
            ],
            'website_scope' => [
                \Magento\Eav\Model\Entity\Attribute\ScopedAttributeInterface::SCOPE_WEBSITE,
                'Website',
            ],
            'store_view_scope' => [
                \Magento\Eav\Model\Entity\Attribute\ScopedAttributeInterface::SCOPE_STORE,
                'Store View',
            ],
        ];
    }

    #[DataProvider('filterableOptionsDataProvider')]
    public function testCreateWarrantyAttribute_givenDifferentFilterableOptions_expectCorrectFilter