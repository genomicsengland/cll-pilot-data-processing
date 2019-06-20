select patno,
    to_date('15/'||seccdiagdateafun, 'DD/MM/YYYY') as seccdiagdateafu,
    secctypeafu,
    null as othtypeafu 
from admire_v5.seccanafu;
