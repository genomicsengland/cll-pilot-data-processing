select patno,
    to_date('15/'||deaddaten, 'DD/MM/YYYY') as deaddate,
    deadcaus,
    null as deadcausoth,
    deadcausdetail,
    deaddisstat,
    othtxdeath,
    seccand 
from admire_v5.death;
