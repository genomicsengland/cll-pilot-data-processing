/*pulls in rows from sequencing manifest that we can attribute to a Flair participant in consent manifest*/
select s.sample_well
	,s.sample_id
	,s.patientid
	,s.deliveryid
	,s.delivery_date
	,s.path
	,s.bam_date
	,s.bam_size
	,s.status
	,s.delivery_version
	,s.build
	,t.patno
from cll_common.sequencing_manifest s 
left join (select * from cll_common.consent_manifest where trial in ('CLLFlair', 'CLLFlair/CLLClear')) c 
	on c.patientid=s.patientid 
left join flair.trialno t 
	on c.trialno=t.trialno
;
