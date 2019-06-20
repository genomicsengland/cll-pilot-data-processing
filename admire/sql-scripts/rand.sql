select patno,
    /*initf03,*/
    extract(year from dob) as yobf03,
    /*nhsnof03,*/
    sexf03,
    racef03,
    trialnof03 
from admire_v5.rand2;
