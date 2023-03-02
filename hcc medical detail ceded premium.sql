
declare @EvaluationPeriodKey int = 20221031
declare @EvaluationDate date = (select DateVal from TMMWarehouse..DimDate where DateKey=@EvaluationPeriodKey )  

if exists (select  * from tempdb.dbo.sysobjects o where o.xtype in ('U') and o.id = object_id(N'tempdb..#a'))
DROP TABLE #a

if exists (select  * from tempdb.dbo.sysobjects o where o.xtype in ('U') and o.id = object_id(N'tempdb..#b'))
DROP TABLE #b

select sum(CededWrittenPremium+(isnull(CededExpRefPremium,0.0))*-1) as SourceCededWrittenPremiumAmount, sum(CededEarnedPremium+isnull(CededExpRefPremium,0.0)*-1) as SourceCededEarnedPremium
from Tmmwarehouse_Staging..src_HCCMedical_Detail_Archive
where FinancialDate = '2022/10'

SELECT
	Sum(WrittenPremiumAmount) as TargetWrittenPremiumAmount,
	SUM(EarnedPremiumAmount) as TargetEarnedPremiumAmount
FROM 
	TMMWarehouse.dbo.FactPremiumAccountingPeriodSnapshot f
JOIN 
	TMMWarehouse.dbo.DimASLOB a ON f.ASLOBKey = a.ASLOBKey
JOIN 
	TMMWarehouse.dbo.DimPolicy p on f.PolicyKey = p.PolicyKey
JOIN 
	TMMWarehouse.dbo.DimCompany c on f.ReportingCompanyKey = c.CompanyKey
WHERE
	f.SourceSystemKey = 4203 and f.AccountingPeriodKey = @EvaluationPeriodKey

select concat(PolicyNumber,'_',PolicyID) as PolicyNumber, sum(CededWrittenPremium+(isnull(CededExpRefPremium,0.0))*-1) as SourceCededWrittenPremiumAmount, sum(CededEarnedPremium+isnull(CededExpRefPremium,0.0)*-1) as SourceCededEarnedPremium
into #a
from Tmmwarehouse_Staging..src_HCCMedical_Detail_Archive
where FinancialDate = '2022/10'
group by concat(PolicyNumber,'_',PolicyID)

SELECT f.PolicyNumber,Sum(WrittenPremiumAmount) as TargetWrittenPremiumAmount,	SUM(EarnedPremiumAmount) as TargetEarnedPremiumAmount
into #b
FROM 
	TMMWarehouse.dbo.FactPremiumAccountingPeriodSnapshot f
JOIN 
	TMMWarehouse.dbo.DimASLOB a ON f.ASLOBKey = a.ASLOBKey
JOIN 
	TMMWarehouse.dbo.DimPolicy p on f.PolicyKey = p.PolicyKey
JOIN 
	TMMWarehouse.dbo.DimCompany c on f.ReportingCompanyKey = c.CompanyKey
WHERE
	f.SourceSystemKey = 4203 and f.AccountingPeriodKey = @EvaluationPeriodKey
	group by f.PolicyNumber

Select
@EvaluationPeriodKey as AccountingPeriodKey,
ISNULL(a.PolicyNumber, b.PolicyNumber) as PolicyNumber,
a.SourceCededWrittenPremiumAmount as SourceCededWrittenPremiumAmount, 
a.SourceCededEarnedPremium as SourceCededEarnedPremium,  
b.TargetWrittenPremiumAmount as TargetWrittenPremiumAmount,
b.TargetEarnedPremiumAmount as TargetEarnedPremiumAmount
From #a a
FULL OUTER JOIN #b b
On a.PolicyNumber = b.PolicyNumber
Where 
IsNull(a.SourceCededWrittenPremiumAmount, 0.00) <> IsNull(b.TargetWrittenPremiumAmount, 0.00) or
IsNull(a.SourceCededEarnedPremium, 0.00)  <> IsNull(b.TargetEarnedPremiumAmount, 0.00) 


