/*
================================================================================
  AfaqElevator Database - SQL Server Script (Fixed)
================================================================================
  التعديلات على النسخة الأصلية:
  1. الـ BIT: بيقبل 1 / 1.0 / True / Yes (بدل ما كل القيم True/False تتحول 0 بصمت)
  2. الأرقام: بتتحول عن طريق DECIMAL الأول عشان '123.0' ما تبقاش NULL
  3. التواريخ: بتتحول بـ style صريح (yyyy-mm-dd ثم dd/mm/yyyy) مش حسب لغة السيرفر
  4. الأعمدة النصية في الجداول النهائية NVARCHAR (دعم العربي) وبعرض أوسع
  5. الـ IDs المكررة جوه الـ CSV بتتشال (صف واحد لكل ID) بدل ما الـ INSERT كله يفشل
  6. كل INSERT جوه TRY/CATCH ويطبع عدد الصفوف أو رسالة الخطأ
  7. فحص جودة (Audit) قبل التحميل: يطلّعلك أي عمود فيه قيم مش قابلة للتحويل
  8. الـ Foreign Keys: تتضاف WITH CHECK، ولو فيه orphans تتضاف WITH NOCHECK وتطبع العدد
  9. الـ Unique Indexes: لو فيه duplicates يتعمل Index عادي بدلها ويطبع تحذير
  10. لو الجداول القديمة (VARCHAR) موجودة، بتتعمل drop وبتتحمّل من جديد
================================================================================
*/

-- ============================================================================
-- 1. إنشاء قاعدة البيانات
-- ============================================================================
IF DB_ID(N'AfaqElevator') IS NULL
    CREATE DATABASE AfaqElevator;
GO

USE AfaqElevator;
GO

-- ============================================================================
-- 2. Schema للـ Staging
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stg')
    EXEC('CREATE SCHEMA stg');
GO

-- ============================================================================
-- 3. حذف جداول Staging القديمة
-- ============================================================================
IF OBJECT_ID('stg.Branches') IS NOT NULL DROP TABLE stg.Branches;
IF OBJECT_ID('stg.Contracts') IS NOT NULL DROP TABLE stg.Contracts;
IF OBJECT_ID('stg.Customers') IS NOT NULL DROP TABLE stg.Customers;
IF OBJECT_ID('stg.Elevators') IS NOT NULL DROP TABLE stg.Elevators;
IF OBJECT_ID('stg.Employees') IS NOT NULL DROP TABLE stg.Employees;
IF OBJECT_ID('stg.Faults') IS NOT NULL DROP TABLE stg.Faults;
IF OBJECT_ID('stg.InventoryTransactions') IS NOT NULL DROP TABLE stg.InventoryTransactions;
IF OBJECT_ID('stg.Invoices') IS NOT NULL DROP TABLE stg.Invoices;
IF OBJECT_ID('stg.MaintenanceVisits') IS NOT NULL DROP TABLE stg.MaintenanceVisits;
IF OBJECT_ID('stg.Parts') IS NOT NULL DROP TABLE stg.Parts;
IF OBJECT_ID('stg.PartsUsage') IS NOT NULL DROP TABLE stg.PartsUsage;
IF OBJECT_ID('stg.Payments') IS NOT NULL DROP TABLE stg.Payments;
IF OBJECT_ID('stg.Projects') IS NOT NULL DROP TABLE stg.Projects;
IF OBJECT_ID('stg.PurchaseOrders') IS NOT NULL DROP TABLE stg.PurchaseOrders;
IF OBJECT_ID('stg.Suppliers') IS NOT NULL DROP TABLE stg.Suppliers;
GO

-- ============================================================================
-- 4. جداول Staging (كل الأعمدة NVARCHAR(MAX))
-- ============================================================================
CREATE TABLE stg.Branches (
    BranchID NVARCHAR(MAX),
    BranchName NVARCHAR(MAX),
    Region NVARCHAR(MAX),
    OpenDate NVARCHAR(MAX),
    ManagerName NVARCHAR(MAX),
    ServiceRadiusKm NVARCHAR(MAX),
    QF_ManagerNameShared NVARCHAR(MAX)
);

CREATE TABLE stg.Contracts (
    ContractID NVARCHAR(MAX),
    ContractNumber NVARCHAR(MAX),
    CustomerID NVARCHAR(MAX),
    ElevatorID NVARCHAR(MAX),
    ContractType NVARCHAR(MAX),
    StartDate NVARCHAR(MAX),
    EndDate NVARCHAR(MAX),
    AnnualValueSAR NVARCHAR(MAX),
    ContractStatus NVARCHAR(MAX),
    RenewalFlag NVARCHAR(MAX),
    QF_ActiveEndedBeforeToday NVARCHAR(MAX),
    AN_DaysStartBeforeCommissioning NVARCHAR(MAX),
    QF_StartsBeforeCommissioning NVARCHAR(MAX),
    QF_WarrantyContractDatesDifferFromElevator NVARCHAR(MAX),
    QF_RenewedNoSuccessorRecord NVARCHAR(MAX)
);

CREATE TABLE stg.Customers (
    CustomerID NVARCHAR(MAX),
    CustomerNumber NVARCHAR(MAX),
    CustomerName NVARCHAR(MAX),
    CustomerType NVARCHAR(MAX),
    BranchID NVARCHAR(MAX),
    City NVARCHAR(MAX),
    AcquisitionDate NVARCHAR(MAX),
    CustomerStatus NVARCHAR(MAX),
    CreditTermsDays NVARCHAR(MAX),
    QF_HasNoElevator NVARCHAR(MAX),
    QF_LostOrDormantWithActiveContract NVARCHAR(MAX)
);

CREATE TABLE stg.Elevators (
    ElevatorID NVARCHAR(MAX),
    ElevatorNumber NVARCHAR(MAX),
    CustomerID NVARCHAR(MAX),
    BranchID NVARCHAR(MAX),
    ElevatorType NVARCHAR(MAX),
    Model NVARCHAR(MAX),
    CapacityKg NVARCHAR(MAX),
    FloorsServed NVARCHAR(MAX),
    CommissioningDate NVARCHAR(MAX),
    CurrentStatus NVARCHAR(MAX),
    UsageLevel NVARCHAR(MAX),
    WarrantyEndDate NVARCHAR(MAX),
    MachineType NVARCHAR(MAX),
    DriveType NVARCHAR(MAX),
    DoorType NVARCHAR(MAX),
    SpeedMps NVARCHAR(MAX),
    InstallationType NVARCHAR(MAX),
    ControllerFamily NVARCHAR(MAX),
    MachineFamily NVARCHAR(MAX),
    QF_CommissionedAfterSnapshot NVARCHAR(MAX),
    QF_CommissionedAfterToday NVARCHAR(MAX)
);

CREATE TABLE stg.Employees (
    EmployeeID NVARCHAR(MAX),
    EmployeeNumber NVARCHAR(MAX),
    EmployeeName NVARCHAR(MAX),
    BranchID NVARCHAR(MAX),
    JobTitle NVARCHAR(MAX),
    HireDate NVARCHAR(MAX),
    EmploymentEndDate NVARCHAR(MAX),
    ExperienceYears NVARCHAR(MAX),
    MonthlySalarySAR NVARCHAR(MAX),
    QF_ExperienceLessThanTenure NVARCHAR(MAX)
);

CREATE TABLE stg.Faults (
    FaultID NVARCHAR(MAX),
    FaultNumber NVARCHAR(MAX),
    ElevatorID NVARCHAR(MAX),
    CustomerID NVARCHAR(MAX),
    VisitID NVARCHAR(MAX),
    TechnicianID NVARCHAR(MAX),
    FaultDate NVARCHAR(MAX),
    FaultCategory NVARCHAR(MAX),
    Severity NVARCHAR(MAX),
    RepairStartDateTime NVARCHAR(MAX),
    RestoredDateTime NVARCHAR(MAX),
    DowntimeHours NVARCHAR(MAX),
    FirstTimeFix NVARCHAR(MAX),
    RepeatFault NVARCHAR(MAX),
    WarrantyCase NVARCHAR(MAX),
    ResolutionStatus NVARCHAR(MAX),
    QF_AfterSnapshot NVARCHAR(MAX),
    QF_AfterToday NVARCHAR(MAX),
    QF_RestoredAfterSnapshot NVARCHAR(MAX),
    AN_InWarrantyWindow NVARCHAR(MAX),
    QF_InWarrantyWindowNotFlagged NVARCHAR(MAX),
    QF_TechnicianBeforeHire NVARCHAR(MAX),
    QF_HydraulicFaultOnNonHydraulicElevator NVARCHAR(MAX),
    QF_RepeatFlagNoPriorSameCategory NVARCHAR(MAX),
    QF_FirstTimeFixAndRepeat NVARCHAR(MAX),
    QF_TechnicianDiffersFromLinkedVisit NVARCHAR(MAX),
    AN_OpenAgeDaysAtSnapshot NVARCHAR(MAX),
    QF_OpenOver90DaysAtSnapshot NVARCHAR(MAX)
);

CREATE TABLE stg.InventoryTransactions (
    TransactionID NVARCHAR(MAX),
    PartID NVARCHAR(MAX),
    BranchID NVARCHAR(MAX),
    TransactionDate NVARCHAR(MAX),
    TransactionType NVARCHAR(MAX),
    Quantity NVARCHAR(MAX),
    UnitCostSAR NVARCHAR(MAX),
    RelatedVisitID NVARCHAR(MAX),
    RelatedFaultID NVARCHAR(MAX),
    StockShortageFlag NVARCHAR(MAX),
    QF_AfterSnapshot NVARCHAR(MAX),
    QF_AfterToday NVARCHAR(MAX),
    QF_BeforeBranchOpen NVARCHAR(MAX),
    AN_StockEffectSign NVARCHAR(MAX),
    AN_SignedQuantity NVARCHAR(MAX),
    AN_StockEffectBasis NVARCHAR(MAX),
    QF_SurplusDuplicateIssue NVARCHAR(MAX),
    QF_PartBranchNegativeBalance NVARCHAR(MAX)
);

CREATE TABLE stg.Invoices (
    InvoiceID NVARCHAR(MAX),
    InvoiceNumber NVARCHAR(MAX),
    CustomerID NVARCHAR(MAX),
    BranchID NVARCHAR(MAX),
    ContractID NVARCHAR(MAX),
    ProjectID NVARCHAR(MAX),
    VisitID NVARCHAR(MAX),
    InvoiceDate NVARCHAR(MAX),
    DueDate NVARCHAR(MAX),
    RevenueCategory NVARCHAR(MAX),
    RevenueSAR NVARCHAR(MAX),
    DirectCostSAR NVARCHAR(MAX),
    InvoiceStatus NVARCHAR(MAX),
    QF_AfterSnapshot NVARCHAR(MAX),
    QF_AfterToday NVARCHAR(MAX),
    QF_DirectCostStatus NVARCHAR(MAX),
    QF_MarginReliability NVARCHAR(MAX),
    QF_NegativeMargin NVARCHAR(MAX),
    QF_SuspectedDuplicateRow NVARCHAR(MAX),
    QF_ProjectCancelled NVARCHAR(MAX),
    AN_GrossProfitSAR NVARCHAR(MAX),
    AN_GrossMarginPct NVARCHAR(MAX),
    AN_GrossProfitSAR_Reliable NVARCHAR(MAX),
    AN_PaidNetSAR NVARCHAR(MAX),
    AN_OutstandingSAR NVARCHAR(MAX),
    AN_SettlementStatusRecalc NVARCHAR(MAX),
    QF_StatusDiffersFromRecalc NVARCHAR(MAX),
    AN_DaysPastDueAtSnapshot NVARCHAR(MAX),
    AN_AgingBucket NVARCHAR(MAX)
);

CREATE TABLE stg.MaintenanceVisits (
    VisitID NVARCHAR(MAX),
    VisitNumber NVARCHAR(MAX),
    ElevatorID NVARCHAR(MAX),
    CustomerID NVARCHAR(MAX),
    ContractID NVARCHAR(MAX),
    TechnicianID NVARCHAR(MAX),
    VisitDate NVARCHAR(MAX),
    MaintenanceType NVARCHAR(MAX),
    VisitStatus NVARCHAR(MAX),
    PlannedDate NVARCHAR(MAX),
    DurationHours NVARCHAR(MAX),
    ChecklistScore NVARCHAR(MAX),
    LaborCostSAR NVARCHAR(MAX),
    CustomerRating NVARCHAR(MAX),
    QF_AfterSnapshot NVARCHAR(MAX),
    QF_AfterToday NVARCHAR(MAX),
    QF_TechnicianBranchDiffersFromElevator NVARCHAR(MAX)
);

CREATE TABLE stg.Parts (
    PartID NVARCHAR(MAX),
    PartNumber NVARCHAR(MAX),
    PartName NVARCHAR(MAX),
    PartCategory NVARCHAR(MAX),
    PrimarySupplierID NVARCHAR(MAX),
    UnitCostSAR NVARCHAR(MAX),
    ReorderLevel NVARCHAR(MAX),
    Criticality NVARCHAR(MAX)
);

CREATE TABLE stg.PartsUsage (
    PartsUsageID NVARCHAR(MAX),
    PartID NVARCHAR(MAX),
    ElevatorID NVARCHAR(MAX),
    VisitID NVARCHAR(MAX),
    FaultID NVARCHAR(MAX),
    TechnicianID NVARCHAR(MAX),
    UsageDate NVARCHAR(MAX),
    QuantityUsed NVARCHAR(MAX),
    UnitCostSAR NVARCHAR(MAX),
    UsageReason NVARCHAR(MAX),
    QF_AfterSnapshot NVARCHAR(MAX),
    QF_AfterToday NVARCHAR(MAX),
    QF_NoMatchingIssueTransaction NVARCHAR(MAX),
    QF_SuspectedDuplicateRow NVARCHAR(MAX)
);

CREATE TABLE stg.Payments (
    PaymentID NVARCHAR(MAX),
    PaymentNumber NVARCHAR(MAX),
    InvoiceID NVARCHAR(MAX),
    CustomerID NVARCHAR(MAX),
    PaymentDate NVARCHAR(MAX),
    PaymentMethod NVARCHAR(MAX),
    PaymentAmountSAR NVARCHAR(MAX),
    PaymentStatus NVARCHAR(MAX),
    DaysAfterInvoice NVARCHAR(MAX),
    AN_SignedPaymentAmountSAR NVARCHAR(MAX),
    QF_RefundStoredPositive NVARCHAR(MAX),
    QF_PaymentUnder1SAR NVARCHAR(MAX)
);

CREATE TABLE stg.Projects (
    ProjectID NVARCHAR(MAX),
    ProjectNumber NVARCHAR(MAX),
    CustomerID NVARCHAR(MAX),
    ElevatorID NVARCHAR(MAX),
    BranchID NVARCHAR(MAX),
    ProjectType NVARCHAR(MAX),
    StartDate NVARCHAR(MAX),
    PlannedEndDate NVARCHAR(MAX),
    ActualEndDate NVARCHAR(MAX),
    ProjectStatus NVARCHAR(MAX),
    BudgetSAR NVARCHAR(MAX),
    ActualCostSAR NVARCHAR(MAX),
    AN_OverrunDays NVARCHAR(MAX),
    AN_DaysPastPlannedEndAtSnapshot NVARCHAR(MAX),
    QF_InProgressPastPlannedEnd NVARCHAR(MAX),
    QF_CompletedAfterPlanWithinTolerance NVARCHAR(MAX),
    QF_CancelledButInvoiced NVARCHAR(MAX)
);

CREATE TABLE stg.PurchaseOrders (
    PurchaseOrderID NVARCHAR(MAX),
    PurchaseOrderNumber NVARCHAR(MAX),
    SupplierID NVARCHAR(MAX),
    PartID NVARCHAR(MAX),
    BranchID NVARCHAR(MAX),
    OrderDate NVARCHAR(MAX),
    ExpectedDeliveryDate NVARCHAR(MAX),
    ActualDeliveryDate NVARCHAR(MAX),
    OrderedQuantity NVARCHAR(MAX),
    UnitCostSAR NVARCHAR(MAX),
    PurchaseOrderStatus NVARCHAR(MAX),
    AN_DeliveryDelayDays NVARCHAR(MAX),
    QF_OpenPastExpectedDelivery NVARCHAR(MAX),
    QF_ReceivedDelayOverlapsLate NVARCHAR(MAX),
    AN_UnitCostVsMasterRatio NVARCHAR(MAX)
);

CREATE TABLE stg.Suppliers (
    SupplierID NVARCHAR(MAX),
    SupplierName NVARCHAR(MAX),
    SupplierCountry NVARCHAR(MAX),
    SupplierRating NVARCHAR(MAX),
    TypicalLeadDays NVARCHAR(MAX),
    PreferredSupplier NVARCHAR(MAX)
);

GO
PRINT 'Staging tables created.';
GO

-- ============================================================================
-- 5. جداول Final
-- ============================================================================
-- لو الجداول القديمة اتعملت بـ VARCHAR، اعمل drop عشان تتعمل بالتعريف الجديد
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID('dbo.Customers') AND c.name = 'CustomerName' AND t.name = 'varchar')
BEGIN
    PRINT 'Old VARCHAR schema detected - dropping old dbo tables...';
    IF OBJECT_ID('dbo.Payments') IS NOT NULL DROP TABLE dbo.Payments;
    IF OBJECT_ID('dbo.PartsUsage') IS NOT NULL DROP TABLE dbo.PartsUsage;
    IF OBJECT_ID('dbo.InventoryTransactions') IS NOT NULL DROP TABLE dbo.InventoryTransactions;
    IF OBJECT_ID('dbo.PurchaseOrders') IS NOT NULL DROP TABLE dbo.PurchaseOrders;
    IF OBJECT_ID('dbo.Invoices') IS NOT NULL DROP TABLE dbo.Invoices;
    IF OBJECT_ID('dbo.Faults') IS NOT NULL DROP TABLE dbo.Faults;
    IF OBJECT_ID('dbo.MaintenanceVisits') IS NOT NULL DROP TABLE dbo.MaintenanceVisits;
    IF OBJECT_ID('dbo.Projects') IS NOT NULL DROP TABLE dbo.Projects;
    IF OBJECT_ID('dbo.Contracts') IS NOT NULL DROP TABLE dbo.Contracts;
    IF OBJECT_ID('dbo.Elevators') IS NOT NULL DROP TABLE dbo.Elevators;
    IF OBJECT_ID('dbo.Parts') IS NOT NULL DROP TABLE dbo.Parts;
    IF OBJECT_ID('dbo.Employees') IS NOT NULL DROP TABLE dbo.Employees;
    IF OBJECT_ID('dbo.Customers') IS NOT NULL DROP TABLE dbo.Customers;
    IF OBJECT_ID('dbo.Suppliers') IS NOT NULL DROP TABLE dbo.Suppliers;
    IF OBJECT_ID('dbo.Branches') IS NOT NULL DROP TABLE dbo.Branches;
END
GO

IF OBJECT_ID('dbo.Branches') IS NULL
CREATE TABLE dbo.Branches (
    BranchID INT NOT NULL PRIMARY KEY,
    BranchName NVARCHAR(50) NOT NULL,
    Region NVARCHAR(50) NOT NULL,
    OpenDate DATE NOT NULL,
    ManagerName NVARCHAR(50) NOT NULL,
    ServiceRadiusKm INT NOT NULL,
    QF_ManagerNameShared BIT NOT NULL
);

IF OBJECT_ID('dbo.Suppliers') IS NULL
CREATE TABLE dbo.Suppliers (
    SupplierID INT NOT NULL PRIMARY KEY,
    SupplierName NVARCHAR(100) NOT NULL,
    SupplierCountry NVARCHAR(50) NOT NULL,
    SupplierRating DECIMAL(2,1) NOT NULL,
    TypicalLeadDays SMALLINT NOT NULL,
    PreferredSupplier BIT NOT NULL
);

IF OBJECT_ID('dbo.Customers') IS NULL
CREATE TABLE dbo.Customers (
    CustomerID INT NOT NULL PRIMARY KEY,
    CustomerNumber NVARCHAR(50) NOT NULL,
    CustomerName NVARCHAR(50) NOT NULL,
    CustomerType NVARCHAR(50) NOT NULL,
    BranchID INT NOT NULL,
    City NVARCHAR(50) NOT NULL,
    AcquisitionDate DATE NOT NULL,
    CustomerStatus NVARCHAR(50) NOT NULL,
    CreditTermsDays SMALLINT NOT NULL,
    QF_HasNoElevator BIT NOT NULL,
    QF_LostOrDormantWithActiveContract BIT NOT NULL
);

IF OBJECT_ID('dbo.Employees') IS NULL
CREATE TABLE dbo.Employees (
    EmployeeID INT NOT NULL PRIMARY KEY,
    EmployeeNumber NVARCHAR(50) NOT NULL,
    EmployeeName NVARCHAR(50) NOT NULL,
    BranchID INT NOT NULL,
    JobTitle NVARCHAR(50) NOT NULL,
    HireDate DATE NOT NULL,
    EmploymentEndDate DATE NULL,
    ExperienceYears DECIMAL(4,1) NOT NULL,
    MonthlySalarySAR DECIMAL(12,2) NOT NULL,
    QF_ExperienceLessThanTenure BIT NOT NULL
);

IF OBJECT_ID('dbo.Parts') IS NULL
CREATE TABLE dbo.Parts (
    PartID INT NOT NULL PRIMARY KEY,
    PartNumber NVARCHAR(50) NOT NULL,
    PartName NVARCHAR(50) NOT NULL,
    PartCategory NVARCHAR(50) NOT NULL,
    PrimarySupplierID INT NOT NULL,
    UnitCostSAR DECIMAL(12,2) NOT NULL,
    ReorderLevel SMALLINT NOT NULL,
    Criticality NVARCHAR(50) NOT NULL
);

IF OBJECT_ID('dbo.Elevators') IS NULL
CREATE TABLE dbo.Elevators (
    ElevatorID INT NOT NULL PRIMARY KEY,
    ElevatorNumber NVARCHAR(50) NOT NULL,
    CustomerID INT NOT NULL,
    BranchID INT NOT NULL,
    ElevatorType NVARCHAR(50) NOT NULL,
    Model NVARCHAR(50) NOT NULL,
    CapacityKg INT NOT NULL,
    FloorsServed SMALLINT NOT NULL,
    CommissioningDate DATE NOT NULL,
    CurrentStatus NVARCHAR(50) NOT NULL,
    UsageLevel NVARCHAR(50) NOT NULL,
    WarrantyEndDate DATE NOT NULL,
    MachineType NVARCHAR(50) NOT NULL,
    DriveType NVARCHAR(50) NOT NULL,
    DoorType NVARCHAR(50) NOT NULL,
    SpeedMps DECIMAL(4,2) NOT NULL,
    InstallationType NVARCHAR(50) NOT NULL,
    ControllerFamily NVARCHAR(50) NOT NULL,
    MachineFamily NVARCHAR(50) NOT NULL,
    QF_CommissionedAfterSnapshot BIT NOT NULL,
    QF_CommissionedAfterToday BIT NOT NULL
);

IF OBJECT_ID('dbo.Contracts') IS NULL
CREATE TABLE dbo.Contracts (
    ContractID INT NOT NULL PRIMARY KEY,
    ContractNumber NVARCHAR(50) NOT NULL,
    CustomerID INT NOT NULL,
    ElevatorID INT NOT NULL,
    ContractType NVARCHAR(50) NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    AnnualValueSAR DECIMAL(12,2) NOT NULL,
    ContractStatus NVARCHAR(50) NOT NULL,
    RenewalFlag NVARCHAR(50) NOT NULL,
    QF_ActiveEndedBeforeToday BIT NOT NULL,
    AN_DaysStartBeforeCommissioning INT NULL,
    QF_StartsBeforeCommissioning BIT NOT NULL,
    QF_WarrantyContractDatesDifferFromElevator BIT NOT NULL,
    QF_RenewedNoSuccessorRecord BIT NOT NULL
);

IF OBJECT_ID('dbo.Projects') IS NULL
CREATE TABLE dbo.Projects (
    ProjectID INT NOT NULL PRIMARY KEY,
    ProjectNumber NVARCHAR(50) NOT NULL,
    CustomerID INT NOT NULL,
    ElevatorID INT NOT NULL,
    BranchID INT NOT NULL,
    ProjectType NVARCHAR(50) NOT NULL,
    StartDate DATE NOT NULL,
    PlannedEndDate DATE NOT NULL,
    ActualEndDate DATE NULL,
    ProjectStatus NVARCHAR(50) NOT NULL,
    BudgetSAR DECIMAL(12,2) NOT NULL,
    ActualCostSAR DECIMAL(12,2) NOT NULL,
    AN_OverrunDays INT NULL,
    AN_DaysPastPlannedEndAtSnapshot INT NULL,
    QF_InProgressPastPlannedEnd BIT NOT NULL,
    QF_CompletedAfterPlanWithinTolerance BIT NOT NULL,
    QF_CancelledButInvoiced BIT NOT NULL
);

IF OBJECT_ID('dbo.MaintenanceVisits') IS NULL
CREATE TABLE dbo.MaintenanceVisits (
    VisitID INT NOT NULL PRIMARY KEY,
    VisitNumber NVARCHAR(50) NOT NULL,
    ElevatorID INT NOT NULL,
    CustomerID INT NOT NULL,
    ContractID INT NULL,
    TechnicianID INT NOT NULL,
    VisitDate DATE NOT NULL,
    MaintenanceType NVARCHAR(50) NOT NULL,
    VisitStatus NVARCHAR(50) NOT NULL,
    PlannedDate DATE NOT NULL,
    DurationHours DECIMAL(8,2) NULL,
    ChecklistScore SMALLINT NULL,
    LaborCostSAR DECIMAL(12,2) NULL,
    CustomerRating SMALLINT NULL,
    QF_AfterSnapshot BIT NOT NULL,
    QF_AfterToday BIT NOT NULL,
    QF_TechnicianBranchDiffersFromElevator BIT NOT NULL
);

IF OBJECT_ID('dbo.Faults') IS NULL
CREATE TABLE dbo.Faults (
    FaultID INT NOT NULL PRIMARY KEY,
    FaultNumber NVARCHAR(50) NOT NULL,
    ElevatorID INT NOT NULL,
    CustomerID INT NOT NULL,
    VisitID INT NULL,
    TechnicianID INT NOT NULL,
    FaultDate DATE NOT NULL,
    FaultCategory NVARCHAR(50) NOT NULL,
    Severity NVARCHAR(50) NOT NULL,
    RepairStartDateTime DATETIME2(0) NOT NULL,
    RestoredDateTime DATETIME2(0) NULL,
    DowntimeHours DECIMAL(8,2) NULL,
    FirstTimeFix BIT NOT NULL,
    RepeatFault BIT NOT NULL,
    WarrantyCase BIT NOT NULL,
    ResolutionStatus NVARCHAR(50) NOT NULL,
    QF_AfterSnapshot BIT NOT NULL,
    QF_AfterToday BIT NOT NULL,
    QF_RestoredAfterSnapshot BIT NOT NULL,
    AN_InWarrantyWindow BIT NOT NULL,
    QF_InWarrantyWindowNotFlagged BIT NOT NULL,
    QF_TechnicianBeforeHire BIT NOT NULL,
    QF_HydraulicFaultOnNonHydraulicElevator BIT NOT NULL,
    QF_RepeatFlagNoPriorSameCategory BIT NOT NULL,
    QF_FirstTimeFixAndRepeat BIT NOT NULL,
    QF_TechnicianDiffersFromLinkedVisit BIT NOT NULL,
    AN_OpenAgeDaysAtSnapshot INT NULL,
    QF_OpenOver90DaysAtSnapshot BIT NOT NULL
);

IF OBJECT_ID('dbo.Invoices') IS NULL
CREATE TABLE dbo.Invoices (
    InvoiceID INT NOT NULL PRIMARY KEY,
    InvoiceNumber NVARCHAR(50) NOT NULL,
    CustomerID INT NOT NULL,
    BranchID INT NOT NULL,
    ContractID INT NULL,
    ProjectID INT NULL,
    VisitID INT NULL,
    InvoiceDate DATE NOT NULL,
    DueDate DATE NOT NULL,
    RevenueCategory NVARCHAR(50) NOT NULL,
    RevenueSAR DECIMAL(12,2) NOT NULL,
    DirectCostSAR DECIMAL(12,2) NOT NULL,
    InvoiceStatus NVARCHAR(50) NOT NULL,
    QF_AfterSnapshot BIT NOT NULL,
    QF_AfterToday BIT NOT NULL,
    QF_DirectCostStatus NVARCHAR(100) NOT NULL,
    QF_MarginReliability NVARCHAR(100) NOT NULL,
    QF_NegativeMargin BIT NOT NULL,
    QF_SuspectedDuplicateRow BIT NOT NULL,
    QF_ProjectCancelled BIT NOT NULL,
    AN_GrossProfitSAR DECIMAL(12,2) NOT NULL,
    AN_GrossMarginPct DECIMAL(10,4) NOT NULL,
    AN_GrossProfitSAR_Reliable DECIMAL(12,2) NULL,
    AN_PaidNetSAR DECIMAL(12,2) NOT NULL,
    AN_OutstandingSAR DECIMAL(12,2) NOT NULL,
    AN_SettlementStatusRecalc NVARCHAR(50) NOT NULL,
    QF_StatusDiffersFromRecalc BIT NOT NULL,
    AN_DaysPastDueAtSnapshot INT NOT NULL,
    AN_AgingBucket NVARCHAR(50) NOT NULL
);

IF OBJECT_ID('dbo.PartsUsage') IS NULL
CREATE TABLE dbo.PartsUsage (
    PartsUsageID INT NOT NULL PRIMARY KEY,
    PartID INT NOT NULL,
    ElevatorID INT NOT NULL,
    VisitID INT NOT NULL,
    FaultID INT NULL,
    TechnicianID INT NOT NULL,
    UsageDate DATE NOT NULL,
    QuantityUsed SMALLINT NOT NULL,
    UnitCostSAR DECIMAL(12,2) NOT NULL,
    UsageReason NVARCHAR(50) NOT NULL,
    QF_AfterSnapshot BIT NOT NULL,
    QF_AfterToday BIT NOT NULL,
    QF_NoMatchingIssueTransaction BIT NOT NULL,
    QF_SuspectedDuplicateRow BIT NOT NULL
);

IF OBJECT_ID('dbo.InventoryTransactions') IS NULL
CREATE TABLE dbo.InventoryTransactions (
    TransactionID INT NOT NULL PRIMARY KEY,
    PartID INT NOT NULL,
    BranchID INT NOT NULL,
    TransactionDate DATE NOT NULL,
    TransactionType NVARCHAR(50) NOT NULL,
    Quantity SMALLINT NOT NULL,
    UnitCostSAR DECIMAL(12,2) NOT NULL,
    RelatedVisitID INT NULL,
    RelatedFaultID INT NULL,
    StockShortageFlag BIT NOT NULL,
    QF_AfterSnapshot BIT NOT NULL,
    QF_AfterToday BIT NOT NULL,
    QF_BeforeBranchOpen BIT NOT NULL,
    AN_StockEffectSign INT NULL,
    AN_SignedQuantity INT NULL,
    AN_StockEffectBasis NVARCHAR(100) NOT NULL,
    QF_SurplusDuplicateIssue BIT NOT NULL,
    QF_PartBranchNegativeBalance BIT NOT NULL
);

IF OBJECT_ID('dbo.PurchaseOrders') IS NULL
CREATE TABLE dbo.PurchaseOrders (
    PurchaseOrderID INT NOT NULL PRIMARY KEY,
    PurchaseOrderNumber NVARCHAR(50) NOT NULL,
    SupplierID INT NOT NULL,
    PartID INT NOT NULL,
    BranchID INT NOT NULL,
    OrderDate DATE NOT NULL,
    ExpectedDeliveryDate DATE NOT NULL,
    ActualDeliveryDate DATE NULL,
    OrderedQuantity SMALLINT NOT NULL,
    UnitCostSAR DECIMAL(12,2) NOT NULL,
    PurchaseOrderStatus NVARCHAR(50) NOT NULL,
    AN_DeliveryDelayDays INT NULL,
    QF_OpenPastExpectedDelivery BIT NOT NULL,
    QF_ReceivedDelayOverlapsLate BIT NOT NULL,
    AN_UnitCostVsMasterRatio DECIMAL(10,4) NOT NULL
);

IF OBJECT_ID('dbo.Payments') IS NULL
CREATE TABLE dbo.Payments (
    PaymentID INT NOT NULL PRIMARY KEY,
    PaymentNumber NVARCHAR(50) NOT NULL,
    InvoiceID INT NOT NULL,
    CustomerID INT NOT NULL,
    PaymentDate DATE NOT NULL,
    PaymentMethod NVARCHAR(50) NOT NULL,
    PaymentAmountSAR DECIMAL(12,2) NOT NULL,
    PaymentStatus NVARCHAR(50) NOT NULL,
    DaysAfterInvoice SMALLINT NOT NULL,
    AN_SignedPaymentAmountSAR DECIMAL(12,2) NOT NULL,
    QF_RefundStoredPositive BIT NOT NULL,
    QF_PaymentUnder1SAR BIT NOT NULL
);

GO
PRINT 'Final tables created.';
GO

-- ============================================================================
-- 6. BULK INSERT (غيّر المسار هنا)
-- ============================================================================
DECLARE @DataPath NVARCHAR(MAX) = N'C:\KSU\Digital Egypt Pioneers\Technical\Team_Project\AfaqCSVs\';   -- <<< غيّر المسار
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'BULK INSERT stg.Branches FROM ''' + @DataPath + N'Branches.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: Branches (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR Branches: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.Contracts FROM ''' + @DataPath + N'Contracts.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: Contracts (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR Contracts: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.Customers FROM ''' + @DataPath + N'Customers.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: Customers (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR Customers: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.Elevators FROM ''' + @DataPath + N'Elevators.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: Elevators (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR Elevators: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.Employees FROM ''' + @DataPath + N'Employees.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: Employees (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR Employees: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.Faults FROM ''' + @DataPath + N'Faults.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: Faults (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR Faults: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.InventoryTransactions FROM ''' + @DataPath + N'InventoryTransactions.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: InventoryTransactions (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR InventoryTransactions: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.Invoices FROM ''' + @DataPath + N'Invoices.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: Invoices (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR Invoices: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.MaintenanceVisits FROM ''' + @DataPath + N'MaintenanceVisits.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: MaintenanceVisits (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR MaintenanceVisits: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.Parts FROM ''' + @DataPath + N'Parts.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: Parts (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR Parts: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.PartsUsage FROM ''' + @DataPath + N'PartsUsage.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: PartsUsage (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR PartsUsage: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.Payments FROM ''' + @DataPath + N'Payments.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: Payments (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR Payments: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.Projects FROM ''' + @DataPath + N'Projects.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: Projects (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR Projects: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.PurchaseOrders FROM ''' + @DataPath + N'PurchaseOrders.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: PurchaseOrders (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR PurchaseOrders: ' + ERROR_MESSAGE(); END CATCH;

SET @sql = N'BULK INSERT stg.Suppliers FROM ''' + @DataPath + N'Suppliers.csv'' WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', TABLOCK, KEEPNULLS);';
BEGIN TRY EXEC sp_executesql @sql; PRINT 'OK: Suppliers (' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows)'; END TRY BEGIN CATCH PRINT 'ERROR Suppliers: ' + ERROR_MESSAGE(); END CATCH;

GO
PRINT 'BULK INSERT finished.';
GO

-- ============================================================================
-- 6b. Audit: فحص القيم اللي مش هتتحول صح (شغّله وراجع النتيجة قبل ما تكمل)
-- ============================================================================
IF OBJECT_ID('tempdb..#audit') IS NOT NULL DROP TABLE #audit;
CREATE TABLE #audit (TableName SYSNAME, ColumnName SYSNAME, TargetType SYSNAME,
                     BadValues INT NULL, BlankInNotNull INT NULL, SampleBad NVARCHAR(100) NULL);

DECLARE @t SYSNAME, @c SYSNAME, @ty SYSNAME, @len INT, @nul BIT, @sql NVARCHAR(MAX), @v NVARCHAR(400), @bad NVARCHAR(MAX);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT o.name, c.name, ty.name, c.max_length, c.is_nullable
    FROM sys.columns c
    JOIN sys.objects o ON o.object_id = c.object_id AND o.schema_id = SCHEMA_ID('dbo') AND o.type = 'U'
    JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    WHERE EXISTS (SELECT 1 FROM sys.tables st WHERE st.name = o.name AND st.schema_id = SCHEMA_ID('stg'))
    ORDER BY o.name, c.column_id;
OPEN cur;
FETCH NEXT FROM cur INTO @t, @c, @ty, @len, @nul;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @v = N'LTRIM(RTRIM(' + QUOTENAME(@c) + N'))';
    SET @bad = CASE
        WHEN @ty IN ('int','smallint','decimal') THEN N'TRY_CONVERT(DECIMAL(18,4), ' + @v + N') IS NULL'
        WHEN @ty = 'date' THEN N'COALESCE(TRY_CONVERT(DATE,LEFT(' + @v + N',10),23),TRY_CONVERT(DATE,LEFT(' + @v + N',10),103)) IS NULL'
        WHEN @ty = 'datetime2' THEN N'COALESCE(TRY_CONVERT(DATETIME2(0),' + @v + N',121),TRY_CONVERT(DATETIME2(0),' + @v + N',103)) IS NULL'
        WHEN @ty = 'bit' THEN N'LOWER(' + @v + N') NOT IN (''1'',''1.0'',''true'',''yes'',''y'',''t'',''0'',''0.0'',''false'',''no'',''n'',''f'')'
        WHEN @ty = 'nvarchar' THEN N'LEN(' + @v + N') > ' + CAST(@len / 2 AS NVARCHAR(10))
        ELSE N'1=0' END;
    SET @sql = N'INSERT #audit SELECT ''' + @t + N''',''' + @c + N''',''' + @ty + N''', '
        + N'SUM(CASE WHEN NULLIF(' + @v + N','''') IS NOT NULL AND ' + @bad + N' THEN 1 ELSE 0 END), '
        + CASE WHEN @nul = 0 THEN N'SUM(CASE WHEN NULLIF(' + @v + N','''') IS NULL THEN 1 ELSE 0 END)' ELSE N'0' END
        + N', LEFT(MIN(CASE WHEN NULLIF(' + @v + N','''') IS NOT NULL AND ' + @bad + N' THEN ' + @v + N' END),100) '
        + N'FROM stg.' + QUOTENAME(@t) + N';';
    EXEC (@sql);
    FETCH NEXT FROM cur INTO @t, @c, @ty, @len, @nul;
END
CLOSE cur; DEALLOCATE cur;

IF EXISTS (SELECT 1 FROM #audit WHERE ISNULL(BadValues,0) > 0 OR ISNULL(BlankInNotNull,0) > 0)
BEGIN
    PRINT 'AUDIT: found columns with problems (see result grid):';
    SELECT * FROM #audit WHERE ISNULL(BadValues,0) > 0 OR ISNULL(BlankInNotNull,0) > 0 ORDER BY TableName, ColumnName;
END
ELSE PRINT 'AUDIT: clean - no conversion problems found.';
GO

-- ============================================================================
-- 7. تحميل البيانات من Staging إلى Final (صف واحد لكل ID)
-- ============================================================================
BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([BranchID])),''))) FROM stg.Branches
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.Branches (BranchID, BranchName, Region, OpenDate, ManagerName, ServiceRadiusKm, QF_ManagerNameShared)
SELECT K,
       LTRIM(RTRIM([BranchName])),
       LTRIM(RTRIM([Region])),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([OpenDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([OpenDate])),''),10),103)),
       LTRIM(RTRIM([ManagerName])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ServiceRadiusKm])),''))),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_ManagerNameShared]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Branches x WHERE x.BranchID = d.K);
PRINT 'Loaded Branches: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading Branches: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([SupplierID])),''))) FROM stg.Suppliers
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.Suppliers (SupplierID, SupplierName, SupplierCountry, SupplierRating, TypicalLeadDays, PreferredSupplier)
SELECT K,
       LTRIM(RTRIM([SupplierName])),
       LTRIM(RTRIM([SupplierCountry])),
       TRY_CONVERT(DECIMAL(2,1), NULLIF(LTRIM(RTRIM([SupplierRating])),'')),
       TRY_CONVERT(SMALLINT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([TypicalLeadDays])),''))),
       CASE WHEN LOWER(LTRIM(RTRIM([PreferredSupplier]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Suppliers x WHERE x.SupplierID = d.K);
PRINT 'Loaded Suppliers: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading Suppliers: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([CustomerID])),''))) FROM stg.Customers
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.Customers (CustomerID, CustomerNumber, CustomerName, CustomerType, BranchID, City, AcquisitionDate, CustomerStatus, CreditTermsDays, QF_HasNoElevator, QF_LostOrDormantWithActiveContract)
SELECT K,
       LTRIM(RTRIM([CustomerNumber])),
       LTRIM(RTRIM([CustomerName])),
       LTRIM(RTRIM([CustomerType])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([BranchID])),''))),
       LTRIM(RTRIM([City])),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([AcquisitionDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([AcquisitionDate])),''),10),103)),
       LTRIM(RTRIM([CustomerStatus])),
       TRY_CONVERT(SMALLINT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([CreditTermsDays])),''))),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_HasNoElevator]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_LostOrDormantWithActiveContract]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Customers x WHERE x.CustomerID = d.K);
PRINT 'Loaded Customers: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading Customers: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([EmployeeID])),''))) FROM stg.Employees
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.Employees (EmployeeID, EmployeeNumber, EmployeeName, BranchID, JobTitle, HireDate, EmploymentEndDate, ExperienceYears, MonthlySalarySAR, QF_ExperienceLessThanTenure)
SELECT K,
       LTRIM(RTRIM([EmployeeNumber])),
       LTRIM(RTRIM([EmployeeName])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([BranchID])),''))),
       LTRIM(RTRIM([JobTitle])),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([HireDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([HireDate])),''),10),103)),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([EmploymentEndDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([EmploymentEndDate])),''),10),103)),
       TRY_CONVERT(DECIMAL(4,1), NULLIF(LTRIM(RTRIM([ExperienceYears])),'')),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([MonthlySalarySAR])),'')),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_ExperienceLessThanTenure]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Employees x WHERE x.EmployeeID = d.K);
PRINT 'Loaded Employees: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading Employees: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([PartID])),''))) FROM stg.Parts
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.Parts (PartID, PartNumber, PartName, PartCategory, PrimarySupplierID, UnitCostSAR, ReorderLevel, Criticality)
SELECT K,
       LTRIM(RTRIM([PartNumber])),
       LTRIM(RTRIM([PartName])),
       LTRIM(RTRIM([PartCategory])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([PrimarySupplierID])),''))),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([UnitCostSAR])),'')),
       TRY_CONVERT(SMALLINT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ReorderLevel])),''))),
       LTRIM(RTRIM([Criticality]))
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Parts x WHERE x.PartID = d.K);
PRINT 'Loaded Parts: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading Parts: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ElevatorID])),''))) FROM stg.Elevators
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.Elevators (ElevatorID, ElevatorNumber, CustomerID, BranchID, ElevatorType, Model, CapacityKg, FloorsServed, CommissioningDate, CurrentStatus, UsageLevel, WarrantyEndDate, MachineType, DriveType, DoorType, SpeedMps, InstallationType, ControllerFamily, MachineFamily, QF_CommissionedAfterSnapshot, QF_CommissionedAfterToday)
SELECT K,
       LTRIM(RTRIM([ElevatorNumber])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([CustomerID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([BranchID])),''))),
       LTRIM(RTRIM([ElevatorType])),
       LTRIM(RTRIM([Model])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([CapacityKg])),''))),
       TRY_CONVERT(SMALLINT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([FloorsServed])),''))),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([CommissioningDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([CommissioningDate])),''),10),103)),
       LTRIM(RTRIM([CurrentStatus])),
       LTRIM(RTRIM([UsageLevel])),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([WarrantyEndDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([WarrantyEndDate])),''),10),103)),
       LTRIM(RTRIM([MachineType])),
       LTRIM(RTRIM([DriveType])),
       LTRIM(RTRIM([DoorType])),
       TRY_CONVERT(DECIMAL(4,2), NULLIF(LTRIM(RTRIM([SpeedMps])),'')),
       LTRIM(RTRIM([InstallationType])),
       LTRIM(RTRIM([ControllerFamily])),
       LTRIM(RTRIM([MachineFamily])),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_CommissionedAfterSnapshot]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_CommissionedAfterToday]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Elevators x WHERE x.ElevatorID = d.K);
PRINT 'Loaded Elevators: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading Elevators: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ContractID])),''))) FROM stg.Contracts
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.Contracts (ContractID, ContractNumber, CustomerID, ElevatorID, ContractType, StartDate, EndDate, AnnualValueSAR, ContractStatus, RenewalFlag, QF_ActiveEndedBeforeToday, AN_DaysStartBeforeCommissioning, QF_StartsBeforeCommissioning, QF_WarrantyContractDatesDifferFromElevator, QF_RenewedNoSuccessorRecord)
SELECT K,
       LTRIM(RTRIM([ContractNumber])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([CustomerID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ElevatorID])),''))),
       LTRIM(RTRIM([ContractType])),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([StartDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([StartDate])),''),10),103)),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([EndDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([EndDate])),''),10),103)),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([AnnualValueSAR])),'')),
       LTRIM(RTRIM([ContractStatus])),
       LTRIM(RTRIM([RenewalFlag])),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_ActiveEndedBeforeToday]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([AN_DaysStartBeforeCommissioning])),''))),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_StartsBeforeCommissioning]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_WarrantyContractDatesDifferFromElevator]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_RenewedNoSuccessorRecord]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Contracts x WHERE x.ContractID = d.K);
PRINT 'Loaded Contracts: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading Contracts: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ProjectID])),''))) FROM stg.Projects
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.Projects (ProjectID, ProjectNumber, CustomerID, ElevatorID, BranchID, ProjectType, StartDate, PlannedEndDate, ActualEndDate, ProjectStatus, BudgetSAR, ActualCostSAR, AN_OverrunDays, AN_DaysPastPlannedEndAtSnapshot, QF_InProgressPastPlannedEnd, QF_CompletedAfterPlanWithinTolerance, QF_CancelledButInvoiced)
SELECT K,
       LTRIM(RTRIM([ProjectNumber])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([CustomerID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ElevatorID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([BranchID])),''))),
       LTRIM(RTRIM([ProjectType])),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([StartDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([StartDate])),''),10),103)),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([PlannedEndDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([PlannedEndDate])),''),10),103)),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([ActualEndDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([ActualEndDate])),''),10),103)),
       LTRIM(RTRIM([ProjectStatus])),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([BudgetSAR])),'')),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([ActualCostSAR])),'')),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([AN_OverrunDays])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([AN_DaysPastPlannedEndAtSnapshot])),''))),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_InProgressPastPlannedEnd]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_CompletedAfterPlanWithinTolerance]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_CancelledButInvoiced]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Projects x WHERE x.ProjectID = d.K);
PRINT 'Loaded Projects: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading Projects: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([VisitID])),''))) FROM stg.MaintenanceVisits
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.MaintenanceVisits (VisitID, VisitNumber, ElevatorID, CustomerID, ContractID, TechnicianID, VisitDate, MaintenanceType, VisitStatus, PlannedDate, DurationHours, ChecklistScore, LaborCostSAR, CustomerRating, QF_AfterSnapshot, QF_AfterToday, QF_TechnicianBranchDiffersFromElevator)
SELECT K,
       LTRIM(RTRIM([VisitNumber])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ElevatorID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([CustomerID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ContractID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([TechnicianID])),''))),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([VisitDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([VisitDate])),''),10),103)),
       LTRIM(RTRIM([MaintenanceType])),
       LTRIM(RTRIM([VisitStatus])),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([PlannedDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([PlannedDate])),''),10),103)),
       TRY_CONVERT(DECIMAL(8,2), NULLIF(LTRIM(RTRIM([DurationHours])),'')),
       TRY_CONVERT(SMALLINT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ChecklistScore])),''))),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([LaborCostSAR])),'')),
       TRY_CONVERT(SMALLINT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([CustomerRating])),''))),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_AfterSnapshot]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_AfterToday]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_TechnicianBranchDiffersFromElevator]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.MaintenanceVisits x WHERE x.VisitID = d.K);
PRINT 'Loaded MaintenanceVisits: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading MaintenanceVisits: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([FaultID])),''))) FROM stg.Faults
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.Faults (FaultID, FaultNumber, ElevatorID, CustomerID, VisitID, TechnicianID, FaultDate, FaultCategory, Severity, RepairStartDateTime, RestoredDateTime, DowntimeHours, FirstTimeFix, RepeatFault, WarrantyCase, ResolutionStatus, QF_AfterSnapshot, QF_AfterToday, QF_RestoredAfterSnapshot, AN_InWarrantyWindow, QF_InWarrantyWindowNotFlagged, QF_TechnicianBeforeHire, QF_HydraulicFaultOnNonHydraulicElevator, QF_RepeatFlagNoPriorSameCategory, QF_FirstTimeFixAndRepeat, QF_TechnicianDiffersFromLinkedVisit, AN_OpenAgeDaysAtSnapshot, QF_OpenOver90DaysAtSnapshot)
SELECT K,
       LTRIM(RTRIM([FaultNumber])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ElevatorID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([CustomerID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([VisitID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([TechnicianID])),''))),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([FaultDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([FaultDate])),''),10),103)),
       LTRIM(RTRIM([FaultCategory])),
       LTRIM(RTRIM([Severity])),
       COALESCE(TRY_CONVERT(DATETIME2(0),NULLIF(LTRIM(RTRIM([RepairStartDateTime])),''),121), TRY_CONVERT(DATETIME2(0),NULLIF(LTRIM(RTRIM([RepairStartDateTime])),''),103)),
       COALESCE(TRY_CONVERT(DATETIME2(0),NULLIF(LTRIM(RTRIM([RestoredDateTime])),''),121), TRY_CONVERT(DATETIME2(0),NULLIF(LTRIM(RTRIM([RestoredDateTime])),''),103)),
       TRY_CONVERT(DECIMAL(8,2), NULLIF(LTRIM(RTRIM([DowntimeHours])),'')),
       CASE WHEN LOWER(LTRIM(RTRIM([FirstTimeFix]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([RepeatFault]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([WarrantyCase]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       LTRIM(RTRIM([ResolutionStatus])),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_AfterSnapshot]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_AfterToday]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_RestoredAfterSnapshot]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([AN_InWarrantyWindow]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_InWarrantyWindowNotFlagged]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_TechnicianBeforeHire]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_HydraulicFaultOnNonHydraulicElevator]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_RepeatFlagNoPriorSameCategory]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_FirstTimeFixAndRepeat]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_TechnicianDiffersFromLinkedVisit]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([AN_OpenAgeDaysAtSnapshot])),''))),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_OpenOver90DaysAtSnapshot]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Faults x WHERE x.FaultID = d.K);
PRINT 'Loaded Faults: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading Faults: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([InvoiceID])),''))) FROM stg.Invoices
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.Invoices (InvoiceID, InvoiceNumber, CustomerID, BranchID, ContractID, ProjectID, VisitID, InvoiceDate, DueDate, RevenueCategory, RevenueSAR, DirectCostSAR, InvoiceStatus, QF_AfterSnapshot, QF_AfterToday, QF_DirectCostStatus, QF_MarginReliability, QF_NegativeMargin, QF_SuspectedDuplicateRow, QF_ProjectCancelled, AN_GrossProfitSAR, AN_GrossMarginPct, AN_GrossProfitSAR_Reliable, AN_PaidNetSAR, AN_OutstandingSAR, AN_SettlementStatusRecalc, QF_StatusDiffersFromRecalc, AN_DaysPastDueAtSnapshot, AN_AgingBucket)
SELECT K,
       LTRIM(RTRIM([InvoiceNumber])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([CustomerID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([BranchID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ContractID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ProjectID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([VisitID])),''))),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([InvoiceDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([InvoiceDate])),''),10),103)),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([DueDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([DueDate])),''),10),103)),
       LTRIM(RTRIM([RevenueCategory])),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([RevenueSAR])),'')),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([DirectCostSAR])),'')),
       LTRIM(RTRIM([InvoiceStatus])),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_AfterSnapshot]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_AfterToday]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       LTRIM(RTRIM([QF_DirectCostStatus])),
       LTRIM(RTRIM([QF_MarginReliability])),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_NegativeMargin]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_SuspectedDuplicateRow]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_ProjectCancelled]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([AN_GrossProfitSAR])),'')),
       TRY_CONVERT(DECIMAL(10,4), NULLIF(LTRIM(RTRIM([AN_GrossMarginPct])),'')),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([AN_GrossProfitSAR_Reliable])),'')),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([AN_PaidNetSAR])),'')),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([AN_OutstandingSAR])),'')),
       LTRIM(RTRIM([AN_SettlementStatusRecalc])),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_StatusDiffersFromRecalc]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([AN_DaysPastDueAtSnapshot])),''))),
       LTRIM(RTRIM([AN_AgingBucket]))
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Invoices x WHERE x.InvoiceID = d.K);
PRINT 'Loaded Invoices: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading Invoices: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([PartsUsageID])),''))) FROM stg.PartsUsage
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.PartsUsage (PartsUsageID, PartID, ElevatorID, VisitID, FaultID, TechnicianID, UsageDate, QuantityUsed, UnitCostSAR, UsageReason, QF_AfterSnapshot, QF_AfterToday, QF_NoMatchingIssueTransaction, QF_SuspectedDuplicateRow)
SELECT K,
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([PartID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([ElevatorID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([VisitID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([FaultID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([TechnicianID])),''))),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([UsageDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([UsageDate])),''),10),103)),
       TRY_CONVERT(SMALLINT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([QuantityUsed])),''))),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([UnitCostSAR])),'')),
       LTRIM(RTRIM([UsageReason])),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_AfterSnapshot]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_AfterToday]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_NoMatchingIssueTransaction]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_SuspectedDuplicateRow]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.PartsUsage x WHERE x.PartsUsageID = d.K);
PRINT 'Loaded PartsUsage: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading PartsUsage: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([TransactionID])),''))) FROM stg.InventoryTransactions
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.InventoryTransactions (TransactionID, PartID, BranchID, TransactionDate, TransactionType, Quantity, UnitCostSAR, RelatedVisitID, RelatedFaultID, StockShortageFlag, QF_AfterSnapshot, QF_AfterToday, QF_BeforeBranchOpen, AN_StockEffectSign, AN_SignedQuantity, AN_StockEffectBasis, QF_SurplusDuplicateIssue, QF_PartBranchNegativeBalance)
SELECT K,
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([PartID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([BranchID])),''))),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([TransactionDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([TransactionDate])),''),10),103)),
       LTRIM(RTRIM([TransactionType])),
       TRY_CONVERT(SMALLINT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([Quantity])),''))),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([UnitCostSAR])),'')),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([RelatedVisitID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([RelatedFaultID])),''))),
       CASE WHEN LOWER(LTRIM(RTRIM([StockShortageFlag]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_AfterSnapshot]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_AfterToday]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_BeforeBranchOpen]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([AN_StockEffectSign])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([AN_SignedQuantity])),''))),
       LTRIM(RTRIM([AN_StockEffectBasis])),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_SurplusDuplicateIssue]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_PartBranchNegativeBalance]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.InventoryTransactions x WHERE x.TransactionID = d.K);
PRINT 'Loaded InventoryTransactions: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading InventoryTransactions: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([PurchaseOrderID])),''))) FROM stg.PurchaseOrders
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.PurchaseOrders (PurchaseOrderID, PurchaseOrderNumber, SupplierID, PartID, BranchID, OrderDate, ExpectedDeliveryDate, ActualDeliveryDate, OrderedQuantity, UnitCostSAR, PurchaseOrderStatus, AN_DeliveryDelayDays, QF_OpenPastExpectedDelivery, QF_ReceivedDelayOverlapsLate, AN_UnitCostVsMasterRatio)
SELECT K,
       LTRIM(RTRIM([PurchaseOrderNumber])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([SupplierID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([PartID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([BranchID])),''))),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([OrderDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([OrderDate])),''),10),103)),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([ExpectedDeliveryDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([ExpectedDeliveryDate])),''),10),103)),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([ActualDeliveryDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([ActualDeliveryDate])),''),10),103)),
       TRY_CONVERT(SMALLINT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([OrderedQuantity])),''))),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([UnitCostSAR])),'')),
       LTRIM(RTRIM([PurchaseOrderStatus])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([AN_DeliveryDelayDays])),''))),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_OpenPastExpectedDelivery]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_ReceivedDelayOverlapsLate]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       TRY_CONVERT(DECIMAL(10,4), NULLIF(LTRIM(RTRIM([AN_UnitCostVsMasterRatio])),''))
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.PurchaseOrders x WHERE x.PurchaseOrderID = d.K);
PRINT 'Loaded PurchaseOrders: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading PurchaseOrders: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY
;WITH s AS (
    SELECT *, K = TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([PaymentID])),''))) FROM stg.Payments
), d AS (
    SELECT *, rn = ROW_NUMBER() OVER (PARTITION BY K ORDER BY (SELECT NULL)) FROM s WHERE K IS NOT NULL
)
INSERT INTO dbo.Payments (PaymentID, PaymentNumber, InvoiceID, CustomerID, PaymentDate, PaymentMethod, PaymentAmountSAR, PaymentStatus, DaysAfterInvoice, AN_SignedPaymentAmountSAR, QF_RefundStoredPositive, QF_PaymentUnder1SAR)
SELECT K,
       LTRIM(RTRIM([PaymentNumber])),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([InvoiceID])),''))),
       TRY_CONVERT(INT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([CustomerID])),''))),
       COALESCE(TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([PaymentDate])),''),10),23), TRY_CONVERT(DATE,LEFT(NULLIF(LTRIM(RTRIM([PaymentDate])),''),10),103)),
       LTRIM(RTRIM([PaymentMethod])),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([PaymentAmountSAR])),'')),
       LTRIM(RTRIM([PaymentStatus])),
       TRY_CONVERT(SMALLINT, TRY_CONVERT(DECIMAL(18,4), NULLIF(LTRIM(RTRIM([DaysAfterInvoice])),''))),
       TRY_CONVERT(DECIMAL(12,2), NULLIF(LTRIM(RTRIM([AN_SignedPaymentAmountSAR])),'')),
       CASE WHEN LOWER(LTRIM(RTRIM([QF_RefundStoredPositive]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(LTRIM(RTRIM([QF_PaymentUnder1SAR]))) IN ('1','1.0','true','yes','y','t') THEN 1 ELSE 0 END
FROM d
WHERE rn = 1 AND NOT EXISTS (SELECT 1 FROM dbo.Payments x WHERE x.PaymentID = d.K);
PRINT 'Loaded Payments: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' rows';
END TRY
BEGIN CATCH PRINT 'ERROR loading Payments: ' + ERROR_MESSAGE(); END CATCH;

GO
PRINT 'Data loaded into final tables.';
GO

-- ============================================================================
-- 8. Foreign Keys (WITH CHECK، ولو فشل -> NOCHECK مع طباعة عدد الـ orphans)
-- ============================================================================
DECLARE @fk TABLE (id INT IDENTITY(1,1), child SYSNAME, col SYSNAME, parent SYSNAME, pcol SYSNAME);
INSERT @fk (child, col, parent, pcol) VALUES
    ('Customers','BranchID','Branches','BranchID'),
    ('Employees','BranchID','Branches','BranchID'),
    ('Elevators','CustomerID','Customers','CustomerID'),
    ('Elevators','BranchID','Branches','BranchID'),
    ('Contracts','CustomerID','Customers','CustomerID'),
    ('Contracts','ElevatorID','Elevators','ElevatorID'),
    ('Projects','CustomerID','Customers','CustomerID'),
    ('Projects','ElevatorID','Elevators','ElevatorID'),
    ('Projects','BranchID','Branches','BranchID'),
    ('MaintenanceVisits','ElevatorID','Elevators','ElevatorID'),
    ('MaintenanceVisits','CustomerID','Customers','CustomerID'),
    ('MaintenanceVisits','ContractID','Contracts','ContractID'),
    ('MaintenanceVisits','TechnicianID','Employees','EmployeeID'),
    ('Faults','ElevatorID','Elevators','ElevatorID'),
    ('Faults','CustomerID','Customers','CustomerID'),
    ('Faults','VisitID','MaintenanceVisits','VisitID'),
    ('Faults','TechnicianID','Employees','EmployeeID'),
    ('Invoices','CustomerID','Customers','CustomerID'),
    ('Invoices','BranchID','Branches','BranchID'),
    ('Invoices','ContractID','Contracts','ContractID'),
    ('Invoices','ProjectID','Projects','ProjectID'),
    ('Invoices','VisitID','MaintenanceVisits','VisitID'),
    ('Payments','InvoiceID','Invoices','InvoiceID'),
    ('Payments','CustomerID','Customers','CustomerID'),
    ('Parts','PrimarySupplierID','Suppliers','SupplierID'),
    ('PartsUsage','PartID','Parts','PartID'),
    ('PartsUsage','ElevatorID','Elevators','ElevatorID'),
    ('PartsUsage','VisitID','MaintenanceVisits','VisitID'),
    ('PartsUsage','FaultID','Faults','FaultID'),
    ('PartsUsage','TechnicianID','Employees','EmployeeID'),
    ('InventoryTransactions','PartID','Parts','PartID'),
    ('InventoryTransactions','BranchID','Branches','BranchID'),
    ('InventoryTransactions','RelatedVisitID','MaintenanceVisits','VisitID'),
    ('InventoryTransactions','RelatedFaultID','Faults','FaultID'),
    ('PurchaseOrders','SupplierID','Suppliers','SupplierID'),
    ('PurchaseOrders','PartID','Parts','PartID'),
    ('PurchaseOrders','BranchID','Branches','BranchID');

DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @fk);
DECLARE @c SYSNAME, @col SYSNAME, @p SYSNAME, @pc SYSNAME, @name SYSNAME, @sql NVARCHAR(MAX), @cnt SQL_VARIANT, @orph INT;
WHILE @i <= @n
BEGIN
    SELECT @c = child, @col = col, @p = parent, @pc = pcol FROM @fk WHERE id = @i;
    SET @name = N'FK_' + @c + N'_' + @p;
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = @name)
    BEGIN
        SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@c) + N' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(@name)
                 + N' FOREIGN KEY (' + QUOTENAME(@col) + N') REFERENCES dbo.' + QUOTENAME(@p) + N'(' + QUOTENAME(@pc) + N');';
        BEGIN TRY
            EXEC sp_executesql @sql;
            PRINT 'FK OK: ' + @name + ' (' + @col + ')';
        END TRY
        BEGIN CATCH
            SET @orph = NULL;
            DECLARE @q NVARCHAR(MAX) = N'SELECT @o = COUNT(*) FROM dbo.' + QUOTENAME(@c) + N' c WHERE c.' + QUOTENAME(@col)
                + N' IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.' + QUOTENAME(@p) + N' p WHERE p.' + QUOTENAME(@pc) + N' = c.' + QUOTENAME(@col) + N');';
            EXEC sp_executesql @q, N'@o INT OUTPUT', @o = @orph OUTPUT;
            PRINT 'FK WARNING (orphans=' + ISNULL(CAST(@orph AS VARCHAR(20)), '?') + ') added WITH NOCHECK: ' + @name + ' (' + @col + ')';
            SET @sql = REPLACE(@sql, N'WITH CHECK', N'WITH NOCHECK');
            BEGIN TRY EXEC sp_executesql @sql; END TRY
            BEGIN CATCH PRINT 'FK FAILED: ' + @name + ' - ' + ERROR_MESSAGE(); END CATCH;
        END CATCH;
    END
    SET @i += 1;
END
GO
PRINT 'Foreign keys done.';
GO

-- ============================================================================
-- 9. Indexes
-- ============================================================================
DECLARE @ix TABLE (id INT IDENTITY(1,1), tbl SYSNAME, col SYSNAME, uniq BIT);
INSERT @ix (tbl, col, uniq) VALUES
    ('Contracts','ContractNumber',1),
    ('Customers','CustomerNumber',1),
    ('Elevators','ElevatorNumber',1),
    ('Employees','EmployeeNumber',1),
    ('Faults','FaultNumber',1),
    ('Invoices','InvoiceNumber',1),
    ('MaintenanceVisits','VisitNumber',1),
    ('Parts','PartNumber',1),
    ('Branches','BranchName',1),
    ('Customers','CustomerName',1),
    ('Employees','EmployeeName',1),
    ('Parts','PartName',1),
    ('Payments','PaymentNumber',1),
    ('Projects','ProjectNumber',1),
    ('PurchaseOrders','PurchaseOrderNumber',1),
    ('Suppliers','SupplierName',1),
    ('Customers','BranchID',0),
    ('Elevators','CustomerID',0),
    ('Elevators','BranchID',0),
    ('Contracts','CustomerID',0),
    ('Contracts','ElevatorID',0),
    ('MaintenanceVisits','ElevatorID',0),
    ('MaintenanceVisits','TechnicianID',0),
    ('Faults','ElevatorID',0),
    ('Faults','TechnicianID',0),
    ('Invoices','CustomerID',0),
    ('Payments','InvoiceID',0),
    ('PartsUsage','VisitID',0),
    ('PartsUsage','PartID',0);

DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @ix);
DECLARE @t SYSNAME, @col SYSNAME, @u BIT, @name SYSNAME, @sql NVARCHAR(MAX);
WHILE @i <= @n
BEGIN
    SELECT @t = tbl, @col = col, @u = uniq FROM @ix WHERE id = @i;
    SET @name = CASE WHEN @u = 1 THEN N'UQ_' ELSE N'IX_' END + @t + N'_' + @col;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = @name AND object_id = OBJECT_ID('dbo.' + @t))
       AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IXN_' + @t + N'_' + @col AND object_id = OBJECT_ID('dbo.' + @t))
    BEGIN
        SET @sql = N'CREATE ' + CASE WHEN @u = 1 THEN N'UNIQUE ' ELSE N'' END + N'NONCLUSTERED INDEX ' + QUOTENAME(@name)
                 + N' ON dbo.' + QUOTENAME(@t) + N'(' + QUOTENAME(@col) + N');';
        BEGIN TRY
            EXEC sp_executesql @sql;
        END TRY
        BEGIN CATCH
            IF @u = 1
            BEGIN
                PRINT 'UNIQUE INDEX FAILED (duplicates in ' + @t + '.' + @col + ') -> created non-unique index instead';
                SET @sql = N'CREATE NONCLUSTERED INDEX ' + QUOTENAME(N'IXN_' + @t + N'_' + @col) + N' ON dbo.' + QUOTENAME(@t) + N'(' + QUOTENAME(@col) + N');';
                EXEC sp_executesql @sql;
            END
            ELSE PRINT 'INDEX FAILED: ' + @name + ' - ' + ERROR_MESSAGE();
        END CATCH;
    END
    SET @i += 1;
END
GO
PRINT 'Indexes done.';
GO

-- Invoices: لازم واحد بس من ContractID / ProjectID / VisitID يكون مليان (حسب الـ metadata)
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Invoices_OneSource')
BEGIN
    BEGIN TRY
        ALTER TABLE dbo.Invoices WITH CHECK ADD CONSTRAINT CK_Invoices_OneSource
            CHECK ((CASE WHEN ContractID IS NULL THEN 0 ELSE 1 END
                  + CASE WHEN ProjectID  IS NULL THEN 0 ELSE 1 END
                  + CASE WHEN VisitID    IS NULL THEN 0 ELSE 1 END) = 1);
        PRINT 'CHECK OK: CK_Invoices_OneSource';
    END TRY
    BEGIN CATCH PRINT 'CHECK FAILED (CK_Invoices_OneSource): ' + ERROR_MESSAGE(); END CATCH;
END
GO

-- ============================================================================
-- 10. Validation
-- ============================================================================
PRINT '========== VALIDATION ==========';

SELECT Tbl, Stg, Final, Expected, Stg - Final AS DroppedRows,
       CASE WHEN Final = Expected THEN 'OK' ELSE 'CHECK' END AS Status
FROM (
SELECT 'Branches' AS Tbl, (SELECT COUNT(*) FROM stg.Branches) AS Stg, (SELECT COUNT(*) FROM dbo.Branches) AS Final, 10 AS Expected
UNION ALL SELECT 'Contracts', (SELECT COUNT(*) FROM stg.Contracts), (SELECT COUNT(*) FROM dbo.Contracts), 8500
UNION ALL SELECT 'Customers', (SELECT COUNT(*) FROM stg.Customers), (SELECT COUNT(*) FROM dbo.Customers), 10000
UNION ALL SELECT 'Elevators', (SELECT COUNT(*) FROM stg.Elevators), (SELECT COUNT(*) FROM dbo.Elevators), 12000
UNION ALL SELECT 'Employees', (SELECT COUNT(*) FROM stg.Employees), (SELECT COUNT(*) FROM dbo.Employees), 420
UNION ALL SELECT 'Faults', (SELECT COUNT(*) FROM stg.Faults), (SELECT COUNT(*) FROM dbo.Faults), 35000
UNION ALL SELECT 'InventoryTransactions', (SELECT COUNT(*) FROM stg.InventoryTransactions), (SELECT COUNT(*) FROM dbo.InventoryTransactions), 70000
UNION ALL SELECT 'Invoices', (SELECT COUNT(*) FROM stg.Invoices), (SELECT COUNT(*) FROM dbo.Invoices), 60000
UNION ALL SELECT 'MaintenanceVisits', (SELECT COUNT(*) FROM stg.MaintenanceVisits), (SELECT COUNT(*) FROM dbo.MaintenanceVisits), 160000
UNION ALL SELECT 'Parts', (SELECT COUNT(*) FROM stg.Parts), (SELECT COUNT(*) FROM dbo.Parts), 900
UNION ALL SELECT 'PartsUsage', (SELECT COUNT(*) FROM stg.PartsUsage), (SELECT COUNT(*) FROM dbo.PartsUsage), 75000
UNION ALL SELECT 'Payments', (SELECT COUNT(*) FROM stg.Payments), (SELECT COUNT(*) FROM dbo.Payments), 70000
UNION ALL SELECT 'Projects', (SELECT COUNT(*) FROM stg.Projects), (SELECT COUNT(*) FROM dbo.Projects), 4000
UNION ALL SELECT 'PurchaseOrders', (SELECT COUNT(*) FROM stg.PurchaseOrders), (SELECT COUNT(*) FROM dbo.PurchaseOrders), 9000
UNION ALL SELECT 'Suppliers', (SELECT COUNT(*) FROM stg.Suppliers), (SELECT COUNT(*) FROM dbo.Suppliers), 75
) v
ORDER BY Tbl;

-- أي FK متضاف WITH NOCHECK (يعني فيه orphans)
SELECT OBJECT_NAME(parent_object_id) AS ChildTable, name AS FKName, is_not_trusted
FROM sys.foreign_keys WHERE is_not_trusted = 1;

-- أي Unique Index اتحوّل لـ non-unique بسبب duplicates
SELECT OBJECT_NAME(object_id) AS TableName, name AS IndexName FROM sys.indexes WHERE name LIKE 'IXN[_]%';

PRINT '========== DONE ==========';
GO
