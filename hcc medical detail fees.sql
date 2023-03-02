
declare @EvaluationPeriodKey int = 20221031
declare @EvaluationDate date = (select DateVal from TMMWarehouse..DimDate where DateKey=@EvaluationPeriodKey )  

if exists (select  * from tempdb.dbo.sysobjects o where o.xtype in ('U') and o.id = object_id(N'tempdb..#a'))
DROP TABLE #a

if exists (select  * from tempdb.dbo.sysobjects o where o.xtype in ('U') and o.id = object_id(N'tempdb..#b'))
DROP TABLE #b

select SUM(CededProducerCommission) as SourceCommissionPaidAmount, 
sum(CededFrontFee+CededMgmtFee) as SourceFeesAmount, 
Sum(CededTax) as SourceTaxesAmount
from Tmmwarehouse_Staging..src_HCCMedical_Detail_Archive
where FinancialDate='2022/10'


select 
	SUM(CommissionPaidAmount) as TargetCommissionPaidAmount,
	SUM(FeesAmount) as TargetFeesAmount,
	SUM(TaxesAmount) as TargetTaxesAmount
FROM 
	TMMWarehouse.dbo.FactMiscFeesAccountingPeriodSnapshot f
JOIN
	TMMWarehouse.dbo.DimASLOB a on f.ASLOBKey = a.ASLOBKey
JOIN
	TMMWarehouse.dbo.DimCompany c on f.ReportingCompanyKey = c.CompanyKey
JOIN
	TMMWarehouse.dbo.DimPolicy p on f.PolicyKey = p.PolicyKey
WHERE 
	f.SourceSystemKey = 4203
and 
	AccountingPeriodKey = @EvaluationPeriodKey

	select concat(PolicyNumber,'_',PolicyID) as PolicyNumber, SUM(CededProducerCommission) as SourceCommissionPaidAmount, 
sum(CededFrontFee+CededMgmtFee) as SourceFeesAmount, 
Sum(CededTax) as SourceTaxesAmount
into #a
from Tmmwarehouse_Staging..src_HCCMedical_Detail_Archive
where FinancialDate='2022/10'
group by concat(PolicyNumber,'_',PolicyID)


select  f.PolicyNumber, SUM(CommissionPaidAmount) as TargetCommissionPaidAmount,
	SUM(FeesAmount) as TargetFeesAmount,
	SUM(TaxesAmount) as TargetTaxesAmount
into #b
FROM 
	TMMWarehouse.dbo.FactMiscFeesAccountingPeriodSnapshot f
JOIN
	TMMWarehouse.dbo.DimASLOB a on f.ASLOBKey = a.ASLOBKey
JOIN
	TMMWarehouse.dbo.DimCompany c on f.ReportingCompanyKey = c.CompanyKey
JOIN
	TMMWarehouse.dbo.DimPolicy p on f.PolicyKey = p.PolicyKey
WHERE 
	f.SourceSystemKey = 4203
and 
	AccountingPeriodKey = @EvaluationPeriodKey
group by f.PolicyNumber

Select
@EvaluationPeriodKey as AccountingPeriodKey,
ISNULL(a.PolicyNumber, b.PolicyNumber) as ClaimNumber,
a.SourceCommissionPaidAmount as SourceCommissionPaidAmount, 
a.SourceFeesAmount as SourceFeesAmount,  
a.SourceTaxesAmount as SourceTaxesAmount, 
b.TargetCommissionPaidAmount as TargetCommissionPaidAmount,
b.TargetFeesAmount as TargetFeesAmount,
b.TargetTaxesAmount as TargetTaxesAmount
From #a a
FULL OUTER JOIN #b b
On a.PolicyNumber = b.PolicyNumber
Where 
IsNull(a.SourceCommissionPaidAmount, 0.00) <> IsNull(b.TargetCommissionPaidAmount, 0.00) or
IsNull(a.SourceFeesAmount, 0.00)  <> IsNull(b.TargetFeesAmount, 0.00)  or
IsNull(a.SourceTaxesAmount, 0.00)  <> IsNull(b.TargetTaxesAmount, 0.00)  	
