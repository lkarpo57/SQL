declare @EvaluationPeriodKey int
set @EvaluationPeriodKey=20220930

declare @PriorEvaluationDate date
set @PriorEvaluationDate = (select MAX(ReportDate) from Phlywarehouse_Staging..src_Torrent_ClaimReserves_Archive where ReportDate<(select Dateval from PHLYWarehouse.dbo.DimDate where DateKey=@EvaluationPeriodKey))

declare @2PriorEvaluationDate date
set @2PriorEvaluationDate = (select MAX(ReportDate) from Phlywarehouse_Staging..src_Torrent_ClaimReserves_Archive where ReportDate<@PriorEvaluationDate)

if exists (select  * from tempdb.dbo.sysobjects o where o.xtype in ('U') and o.id = object_id(N'tempdb..#a'))
DROP TABLE #a

if exists (select  * from tempdb.dbo.sysobjects o where o.xtype in ('U') and o.id = object_id(N'tempdb..#b'))
DROP TABLE #b

if exists (select  * from tempdb.dbo.sysobjects o where o.xtype in ('U') and o.id = object_id(N'tempdb..#c'))
DROP TABLE #c

select AccountingPeriodKey, prem.PolicyNumber, PremiumStateCode as PremiumStateCode, ReportingCompany as ReportingCompany, cov.ProductCode as ProductCode, 
asl.ASLOBCode as ASLOBCode,cov.ExperienceProduct as ExperienceProduct, p.BusinessType as BusinessType,
TargetWrittenPremiumAmount=sum(WrittenPremiumAmount),TargetEarnedPremiumAmount=sum(EarnedPremiumAmount) 
into #a
from phlywarehouse.dbo.FactPremiumAccountingPeriodSnapshot prem
left join phlywarehouse.dbo.DimASLOB asl on prem.ASLOBKey=asl.ASLOBKey
left join phlywarehouse.dbo.DimCoverageProductSubline cov on prem.CoverageKey=cov.CoverageKey
left join phlywarehouse.dbo.DimPolicy p on prem.PolicyKey=p.PolicyKey
where prem.SourceSystemKey = 107 and prem.AccountingPeriodKey=@EvaluationPeriodKey
group by AccountingPeriodKey, prem.PolicyNumber, PremiumStateCode, ReportingCompany, cov.ProductCode, asl.ASLOBCode, cov.ExperienceProduct, p.BusinessType

select @EvaluationPeriodKey as AccountingPeriodKey, PolicyNumber,PremiumStateCode, 'PH' as ReportingCompany, 
'FL' as ProductCode, '23' as ASLOBCode, '61' as ExperienceProductCode, 'Direct' as BusinessType, SUM(WP) as SourceWrittenPremiumAmount, SUM(WP-UPRChange) as SourceEarnedPremiumAmount 
into #b
from (

select PolicyNumber+convert(varchar(4),year(EffectiveDate)) as PolicyNumber, State as PremiumStateCode, SUM(UnearnedWrittenPremium) as UPRChange, 0 as WP
from PHLYWarehouse_Staging.dbo.src_Torrent_UnearnedPremium_Archive where ReportDate = @PriorEvaluationDate
group by PolicyNumber+convert(varchar(4),year(EffectiveDate)), State
UNION ALL
select PolicyNumber+convert(varchar(4),year(EffectiveDate)) as PolicyNumber, State as PremiumStateCode, SUM(UnearnedWrittenPremium*-1) as UPRChange, 0 as WP
from PHLYWarehouse_Staging.dbo.src_Torrent_UnearnedPremium_Archive where ReportDate =@2PriorEvaluationDate
group by PolicyNumber+convert(varchar(4),year(EffectiveDate)), State
UNION ALL
select PolicyNumber+convert(varchar(4),year(PolicyEffectiveDate)) as PolicyNumber, PropertyState as PremiumStateCode, 0 as UPRChange, SUM(TotalWrittenPremium) as WP
from PHLYWarehouse_Staging.dbo.src_Torrent_WrittenPremium_Archive 
where ReportDate = @PriorEvaluationDate
group by PolicyNumber+convert(varchar(4),year(PolicyEffectiveDate)), PropertyState

)a
group by PolicyNumber, PremiumStateCode

select b.AccountingPeriodKey, sum(b.SourceWrittenPremiumAmount) as SourceWrittenPremiumAmount, sum(b.SourceEarnedPremiumAmount) as SourceEarnedPremiumAmount
into #c
from #b b
group by b.AccountingPeriodKey

select @EvaluationPeriodKey as AccountingPeriodKey,c.SourceWrittenPremiumAmount, a.TargetWrittenPremiumAmount, c.SourceEarnedPremiumAmount , a.TargetEarnedPremiumAmount
from (select sum(TargetWrittenPremiumAmount) as TargetWrittenPremiumAmount, sum(TargetEarnedPremiumAmount) as TargetEarnedPremiumAmount from #a) a
cross join
(select sum(SourceWrittenPremiumAmount) as SourceWrittenPremiumAmount, sum(SourceEarnedPremiumAmount) as SourceEarnedPremiumAmount from #c) c



select isnull(a.AccountingPeriodKey, b.AccountingPeriodKey) as AccountingPeriodKey, isnull(a.PolicyNumber,b.PolicyNumber) as PolicyNumber, 
isnull(a.PremiumStateCode,b.PremiumStateCode) as PremiumStateCode, isnull(a.ReportingCompany,b.ReportingCompany) as ReportingCompany, isnull(a.ProductCode, b.ProductCode) as ProductCode,
isnull(a.ASLOBCode,b.ASLOBCode) as ASLOBCode, isnull(a.ExperienceProduct,b.ExperienceProductCode) as ExperienceProduct, isnull(a.BusinessType,b.BusinessType) as BusinessType,
b.SourceWrittenPremiumAmount as SourceWrittenPremiumAmount, a.TargetWrittenPremiumAmount as TargetWrittenPremiumAmount, 
b.SourceEarnedPremiumAmount as SourceEarnedPremiumAmount, a.TargetEarnedPremiumAmount as TargetEarnedPremiumAmount
from #a a 
full join #b b on a.AccountingPeriodKey=b.AccountingPeriodKey and a.PolicyNumber=b.PolicyNumber and a.PremiumStateCode=b.PremiumStateCode
Where 
	(((IsNull(a.TargetWrittenPremiumAmount, 0.00) +.5) <= IsNull(b.SourceWrittenPremiumAmount, 0.00)) OR ((IsNull(a.TargetWrittenPremiumAmount, 0.00) -.5) >= IsNull(b.SourceWrittenPremiumAmount, 0.00)))
OR
	(((IsNull(a.TargetEarnedPremiumAmount, 0.00) +.5) <= IsNull(b.SourceEarnedPremiumAmount, 0.00)) OR ((IsNull(a.TargetEarnedPremiumAmount, 0.00) -.5) >= IsNull(b.SourceEarnedPremiumAmount, 0.00)))
order by isnull(a.PolicyNumber,b.PolicyNumber)
