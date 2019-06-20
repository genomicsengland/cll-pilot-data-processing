select patno,
    othtxname18m,
    null as othtxnameoth18m,
    to_date('15/'||othtxsdate18mn, 'DD/MM/YYYY') as othtxsdate18m,
    othtxstop18m,
    to_date('15/'||othtxedate18mn, 'DD/MM/YYYY') as othtxedate18m,
    othtxresp18m,
    othtxreas18m,
    null as othtxreasoth18m,
    trial18m,
    null as trialname18m,
    null as trialnameoth18m 
from admire_v5.othtx18m;
