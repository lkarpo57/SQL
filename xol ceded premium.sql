declare @EvaluationPeriodKey int
set @EvaluationPeriodKey=20221031

declare @EvaluationDate date
set @EvaluationDate=(select Dateval from TMMWarehouse.dbo.DimDate where DateKey=@EvaluationPeriodKey)

if exists (select  * from tempdb.dbo.sysobjects o where o.xtype in ('U') and o.id = object_id(N'tempdb..#a'))
DROP TABLE #a

if exists (select  * from tempdb.dbo.sysobjects o where o.xtype in ('U') and o.id = object_id(N'tempdb..#b'))
DROP TABLE #b

select convert(varchar,TransactionDate, 112) as TransactionDate, 
Sum(TotalPremiumAmount) as sourceCededWrittenPremium, Sum(TotalPremiumAmount) as sourceCededEarnedPremium
from TMMWarehouse_Staging.dbo.src_XOL_Premium_Archive xol
left join 
	TMMWarehouse_Staging.dbo.STG_Coverage_Mapping_XOL (nolock) cov on cov.ASLOBCode = xol.ASLOBCode
											and cov.CommonLOBDescription = xol.CommonLOBDescription	
WHERE TransactionDate = @EvaluationDate
group by TransactionDate

SELECT AccountingPeriodKey, 
sum(CededWrittenPremiumAmount) as TargetCededWrittenPremium, sum(CededEarnedPremiumAmount) as TargetCededEarnedPremium
FROM tmmwarehouse.dbo.FactCededPremiumAccountingPeriodSnapshot f
JOIN TMMWarehouse.dbo.DimCompany c ON f.ReportingCompanyKey = c.CompanyKey
JOIN TMMWarehouse.dbo.DimASLOB a ON f.ASLOBKey = a.ASLOBKey
JOIN TMMWarehouse.dbo.DimCoverage cov on f.CoverageKey = cov.CoverageKey
JOIN TMMWarehouse.dbo.DimPolicy p on f.PolicyKey = p.PolicyKey
WHERE 
	f.SourceSystemKey = 1203
	and 
	AccountingPeriodKey = @EvaluationPeriodKey
group by AccountingPeriodKey

select convert(varchar,TransactionDate, 112) as TransactionDate, 
 CompanyCode as ReportingCompany, 
xol.ASLOBCode as ASLOB, 
isnull(cov.LOBTypeCode,'Unknown') as LOBTypeCode, 
Sum(TotalPremiumAmount) as sourceCededWrittenPremium, Sum(TotalPremiumAmount) as sourceCededEarnedPremium
into #a
from TMMWarehouse_Staging.dbo.src_XOL_Premium_Archive xol
left join 
	TMMWarehouse_Staging.dbo.STG_Coverage_Mapping_XOL (nolock) cov on cov.ASLOBCode = xol.ASLOBCode
											and cov.CommonLOBDescription = xol.CommonLOBDescription	
WHERE TransactionDate = @EvaluationDate
group by TransactionDate
, CompanyCode, xol.ASLOBCode, isnull(cov.LOBTypeCode,'Unknown')

--select convert(varchar,TransactionDate, 112) as TransactionDate, 
-- CompanyCode as ReportingCompany, 
--xol.ASLOBCode as ASLOB, 
--isnull(xol.CommonLOBDescription,'Unknown') as LOBTypeCode, 
--Sum(AffiliatePremiumAmount+NonAffiliatePremiumAmount) as sourceCededWrittenPremium, Sum(AffiliatePremiumAmount+NonAffiliatePremiumAmount) as sourceCededEarnedPremium
--from TMMWarehouse_Staging.dbo.src_XOL_Premium_Transaction xol
--where TransactionDate >= '2022-01-31 00:00:00.000'
--group by convert(varchar,TransactionDate, 112), CompanyCode, xol.ASLOBCode, xol.CommonLOBDescription

SELECT AccountingPeriodKey, 
c.CompanyCode as ReportingCompany, a.ASLOBCode as ASLOB, cov.LOBTypeCode, 
sum(CededWrittenPremiumAmount) as TargetCededWrittenPremium, sum(CededEarnedPremiumAmount) as TargetCededEarnedPremium
into #b
FROM tmmwarehouse.dbo.FactCededPremiumAccountingPeriodSnapshot f
JOIN TMMWarehouse.dbo.DimCompany c ON f.ReportingCompanyKey = c.CompanyKey
JOIN TMMWarehouse.dbo.DimASLOB a ON f.ASLOBKey = a.ASLOBKey
JOIN TMMWarehouse.dbo.DimCoverage cov on f.CoverageKey = cov.CoverageKey
JOIN TMMWarehouse.dbo.DimPolicy p on f.PolicyKey = p.PolicyKey
WHERE 
	f.SourceSystemKey = 1203
	and 
	AccountingPeriodKey = @EvaluationPeriodKey
group by AccountingPeriodKey
, c.CompanyCode, a.ASLOBCode, cov.LOBTypeCode
Select
@EvaluationPeriodKey,
'XOL',
ISNULL(a.ReportingCompany, b.ReportingCompany),
ISNULL(a.ASLOB, b.ASLOB),
ISNULL(a.LobTypeCode, b.LobTypeCode),
a.sourceCededWrittenPremium as SourceCededWrittenPremium, 
a.sourceCededEarnedPremium as SourceCededEarnedPremium,  
b.TargetCededWrittenPremium as TargetCededWrittenPremium, 
b.TargetCededEarnedPremium as TargetCededEarnedPremium

 From #a a
FULL OUTER JOIN 
#b b
On a.ReportingCompany = b.ReportingCompany
And a.ASLOB = b.ASLOB
and a.lobtypecode = b.lobtypecode

Where 

IsNull(a.sourceCededWrittenPremium, 0.00) <> IsNull(b.TargetCededWrittenPremium, 0.00) or
IsNull(a.sourceCededEarnedPremium, 0.00)  <> IsNull(b.TargetCededEarnedPremium, 0.00)  	