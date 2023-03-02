declare @EvaluationPeriodKey int
set @EvaluationPeriodKey=20230131

if exists (select  * from tempdb.dbo.sysobjects o where o.xtype in ('U') and o.id = object_id(N'tempdb..#A'))
DROP TABLE #A
 

if exists (select  * from tempdb.dbo.sysobjects o where o.xtype in ('U') and o.id = object_id(N'tempdb..#B'))
DROP TABLE #B

declare @EvaluationPeriod date
set @EvaluationPeriod= CONVERT(datetime,convert(char(8), @EvaluationPeriodKey)) 


select ReportingCompany, YEAR(LossDate) as AccidentYear, ExperienceProduct, ProductCode, PremiumStateCode, 'Direct'as BusinessType

,sum(case when (TransactionCategory = 'Reserve' AND TransactionType not in ('Adjusting and Other','Defense and Cost Containment')) or (TransactionType = 'Unknown' AND TransactionType = 'None') then TransactionAmount else 0 end) as CaseLoss
,sum(case when TransactionCategory = 'Reserve'  AND TransactionType = 'Defense and Cost Containment' then TransactionAmount else 0 end) as CaseDCC
,sum(case when TransactionCategory = 'Reserve'  AND TransactionType = 'Adjusting and Other' then TransactionAmount else 0 end) as CaseANO
,sum(case when TransactionCategory = 'Payment' AND TransactionType not in ('Adjusting and Other','Defense and Cost Containment') then TransactionAmount else 0 end) as PaidLoss
,sum(case when TransactionCategory = 'Payment'  AND TransactionType = 'Defense and Cost Containment' then TransactionAmount else 0 end)  as PaidDCC
,sum(case when TransactionCategory = 'Payment'  AND TransactionType = 'Adjusting and Other' then TransactionAmount else 0 end) as PaidANO
into #A
from dbo.src_AJ_Flood_Monthly
where ProcessDate> @EvaluationPeriod
group by ReportingCompany, YEAR(LossDate), ExperienceProduct, ProductCode, PremiumStateCode

Select 
       Convert(Varchar(2), F.ReportingCompany) as [ReportingCompany],
       Convert(Int, dld.YearVal) as [AccidentYear],
	   Convert(Varchar(5), dcps.ExperienceProduct) as [ExperienceProduct],
	   Convert(Varchar(2), dcps.ProductCode) as [ProductCode],
	   Convert(Varchar(2), F.PremiumStateCode) as [StateCode],
	   dp.BusinessType as BusinessType,
	   Convert(Money, Sum([Paid Loss])) as [PaidLoss],
	   Convert(Money, Sum([DCCPaidAmount])) as [PaidDCC],
	   Convert(Money, Sum([ANOPaidAmount])) as [PaidANO],
	   Convert(Money, Sum([Case Loss])) as [CaseLoss],
	   Convert(Money, Sum([DCCReserveAmount])) as [CaseDCC],
	   Convert(Money, Sum([ANOReserveAmount])) as [CaseANO]
INTO #B
From PHLYWarehouse..FactClaimAccountingPeriodSnapshot F
join PHLYWarehouse..DimDate dad on f.AccountingPeriodKey=dad.DateKey
join PHLYWarehouse..dimclaim dc on f.ClaimNumber=dc.ClaimNumber
and dc.RowEffectiveDate<dad.FirstDayOfNextMonth and dc.RowExpirationDate>=FirstDayOfNextMonth
join PHLYWarehouse..DimCoverageProductSubline dcps on f.CoverageKey=dcps.CoverageKey
join PHLYWarehouse..DimDate dld on dc.LossDate=dld.DateKey
join PHLYWarehouse..DimSourceSystem dss on f.SourceSystemKey=dss.SourceSystemKey
join PHLYWarehouse..DimPolicy dp on f.PolicyKey=dp.PolicyKey
Where f.AccountingPeriodKey=@EvaluationPeriodKey
And dss.SourceSystemKey = 82
Group By dld.Yearval, F.ReportingCompany, F.PremiumStateCode, dcps.ProductCode, dcps.ExperienceProduct,dp.BusinessType
Having  SUM([Paid Loss]) <>0.00 or SUM([DCCPaidAmount]) <>0.00 or SUM([ANOPaidAmount]) <>0.00 
or SUM([Case Loss]) <>0.00 or SUM([DCCReserveAmount]) <>0.00 or SUM([ANOReserveAmount]) <>0.00

select 
	@EvaluationPeriodKey as AccountingPeriod,
	a.PaidLoss as SourcePaidLoss, 
	a.PaidDCC as SourcePaidDCC, 
	a.PaidANO as SourcePaidANO, 
	a.CaseLoss as SourceCaseLoss, 
	a.CaseDCC as SourceCaseDCC, 
	a.CaseANO as SourceCaseANO,
	b.PaidLoss as TargetPaidLoss, 
	b.PaidDCC as TargetPaidDCC, 
	b.PaidANO as TargetPaidANO, 
	b.CaseLoss as TargetCaseLoss, 
	b.CaseDCC as TargetCaseDCC, 
	b.CaseANO as TargetCaseANO 
from (
select sum(PaidLoss) as PaidLoss, sum(PaidDCC) as PaidDCC, sum(PaidANO) as PaidANO, sum(CaseLoss) as CaseLoss, sum(CaseDCC) as CaseDCC, sum(CaseANO) as CaseANO from #A) a
cross join
(select sum(PaidLoss) as PaidLoss, sum(PaidDCC) as PaidDCC, sum(PaidANO) as PaidANO, sum(CaseLoss) as CaseLoss, sum(CaseDCC) as CaseDCC, sum(CaseANO) as CaseANO from #B) b

  Select
@EvaluationPeriodKey as AccountingPeriod,
ISNULL(a.ReportingCompany, b.ReportingCompany) as ReportingCompany,
ISNULL(a.AccidentYear, b.AccidentYear) as AccidentYear,
ISNULL(a.ExperienceProduct, b.ExperienceProduct) as ExperienceProduct,
ISNULL(a.ProductCode, b.ProductCode) as ProductCode,
ISNULL(a.PremiumStateCode, b.StateCode) as PremiumStateCode,
ISNULL(a.BusinessType, b.BusinessType) as BusinessType,
a.PaidLoss as SourcePaidLoss, 
a.PaidDCC as SourcePaidDCC, 
a.PaidANO as SourcePaidANO, 
a.CaseLoss as SourceCaseLoss, 
a.CaseDCC as SourceCaseDCC, 
a.CaseANO as SourceCaseANO,
b.PaidLoss as TargetPaidLoss, 
b.PaidDCC as TargetPaidDCC, 
b.PaidANO as TargetPaidANO, 
b.CaseLoss as TargetCaseLoss, 
b.CaseDCC as TargetCaseDCC, 
b.CaseANO as TargetCaseANO 
 From #A a
FULL OUTER JOIN 
#B b
On a.ReportingCompany = b.ReportingCompany
And a.AccidentYear = b.AccidentYear
And a.ExperienceProduct = b.ExperienceProduct
And a.ProductCode = b.ProductCode
And a.PremiumStateCode = b.StateCode
And a.BusinessType = b.BusinessType

Where 
	(((IsNull(b.PaidLoss, 0.00) +.5) <= IsNull(a.PaidLoss, 0.00)) OR ((IsNull(b.PaidLoss, 0.00) -.5) >= IsNull(a.PaidLoss, 0.00)))
OR
	(((IsNull(b.PaidDCC, 0.00) +.5) <= IsNull(a.PaidDCC, 0.00)) OR ((IsNull(b.PaidDCC, 0.00) -.5) >= IsNull(a.PaidDCC, 0.00)))
OR
	(((IsNull(b.PaidANO, 0.00) +.5) <= IsNull(a.PaidANO, 0.00)) OR ((IsNull(b.PaidANO, 0.00) -.5) >= IsNull(a.PaidANO, 0.00)))
OR
	(((IsNull(b.CaseLoss, 0.00) +.5) <= IsNull(a.CaseLoss, 0.00)) OR ((IsNull(b.CaseLoss, 0.00) -.5) >= IsNull(a.CaseLoss, 0.00)))
OR
	(((IsNull(b.CaseDCC, 0.00) +.5) <= IsNull(a.CaseDCC, 0.00)) OR ((IsNull(b.CaseDCC, 0.00) -.5) >= IsNull(a.CaseDCC, 0.00)))
OR
	(((IsNull(b.CaseANO, 0.00) +.5) <= IsNull(a.CaseANO, 0.00)) OR ((IsNull(b.CaseANO, 0.00) -.5) >= IsNull(a.CaseANO, 0.00)))	

