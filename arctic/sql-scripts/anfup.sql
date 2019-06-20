select patno,
    aliveafu,
    to_date('15/'||alivedateafun, 'DD/MM/YYYY') as alivedateafu,
    pprogafu,
    othtxafu,
    seccanafu 
from arctic_v5.anfup;
