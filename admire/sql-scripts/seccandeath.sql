select patno
	,secctyped
	,to_date('15/'||seccdiagdatedn, 'DD/MM/YYYY') as seccdiagdate
from admire_v5.seccandeath;
