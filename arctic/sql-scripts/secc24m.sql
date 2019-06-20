select patno,
    to_date('15/'||seccdiagdatef12n, 'DD/MM/YYYY') as seccdiagdatef12,
    secctypef12,
    null as othtypef12 
from arctic_v5.secc24m;
