/*pulls in rows from sequencing manifest that we can attribute to an Arctic participant in consent manifest*/
select s.patientid
	,s.sample_well
	,s.sample_id
	,s.deliveryid
	,s.delivery_date
	,s.path
	,s.bam_date
	,s.bam_size
	,s.status
	,s.delivery_version
	,s.build
	,t.patno
	,t.trialno
from cll_common.sequencing_manifest s 
left join (select * from cll_common.consent_manifest where trial in ('Arctic')) c 
	on c.patientid=s.patientid 
left join arctic_v4.trialno t 
	on c.trialno=t.trialno
;
