select patno,
    to_date('15/'||seccdiagdatedn, 'DD/MM/YYYY') as seccdiagdated,
    secctyped,
    null as othtyped 
from arctic_v5.seccd;
