select patno,
    alive24m,
    to_date('15/'||alivedate24mn, 'DD/MM/YYYY') as alivedate24m,
    progress24m,
    othtx24m,
    to_date('15/'||ppdate24mn, 'DD/MM/YYYY') as ppdate24m,
    pptype24m,
    ppconc24m,
    siga24m,
    sigg24m,
    sigm24m,
    to_date('15/'||assessdate24mn, 'DD/MM/YYYY') as assessdate24m,
    systobp24m,
    diastbp24m,
    pulse24m,
    temp24m,
    weight24m,
    height24,
    bsa24,
    gcsf24,
    who24,
    ctscan24m,
    to_date('15/'||ctdate24mn, 'DD/MM/YYYY') as ctdate24m,
    ctpleeff24m,
    ctpereff24m,
    ctextra24m,
    thonodinv24m,
    abdnodinv24m,
    pelnodinv24m,
    physlymasses24m,
    to_date('15/'||lymassesdate24mn, 'DD/MM/YYYY') as lymassesdate24m,
    cernodsize24m,
    supnodsize24m,
    axinodsize24m,
    ingnodsize24m,
    livassess24m,
    to_date('15/'||livassesdate24mn, 'DD/MM/YYYY') as livassesdate24m,
    livassesscm24m,
    splenect24m,
    splenectcm24m,
    to_date('15/'||fbcdate24mn, 'DD/MM/YYYY') as fbcdate24m,
    hb24m,
    plts24m,
    wbc24m,
    ancneuphil24m,
    alclympcyt24m,
    mrdassess24m,
    mrdhmds24m,
    sign24m,
    mrdpct24m,
    iwcll24m,
    seccanf12 
from admire_v5.m24postran;
