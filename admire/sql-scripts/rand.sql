select patno,
    /*initf03,*/
    extract(year from dobf03) as yobf03,
    /*nhsnof03,*/
    sexf03,
    racef03,
    trialnof03 
from admire_v2.rand;
