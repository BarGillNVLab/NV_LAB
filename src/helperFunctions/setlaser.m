function setlaser(amp)
% ofir hacker 1.11.22
% the function chenge the AOM power to num' between 0 and 1  
 laser = getObjByName('Green Laser');
    if amp<1 && amp>0
        
        laser.aom.value=amp;
    else
        error("laser aom power should be 0<amp<1")
    end
end