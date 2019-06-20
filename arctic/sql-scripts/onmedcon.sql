select patno,
    medcondname,
    null as medcondnameoth,
    to_date('15/'||medcondsdatenew, 'DD/MM/YYYY') as medcondsdate,
    medcondtrt,
    null as medcondtrtoth,
    to_date('15/'||mctrtsdatenew, 'DD/MM/YYYY') as mctrtsdate,
    null as mctrtstop,
    to_date('15/'||mctrtedatenew, 'DD/MM/YYYY') as mctrtedate 
from arctic_v5.onmedcon;
