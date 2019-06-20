select patno,
    othtxnameafu,
    null as othtxnameothafu,
    to_date('15/'||othtxsdateafun, 'DD/MM/YYYY') as othtxsdateafu,
    othtxstopafu,
    to_date('15/'||othtxedateafun, 'DD/MM/YYYY') as othtxedateafu,
    othtxrespafu,
    othtxreasafu,
    null as othtxreasothafu,
    null as trialafu,
    trialnameafu,
    null as trialnameothafu 
from admire_v5.othtxafu;
