function sPath = getSysPath(oVsys)
%CONVERTSHORTHANDTOFULLPATH Summary of this function goes here
%   Detailed explanation goes here


    sPath = '';
    
    while ~isa(oVsys, 'systems.root')
        
        sPath = [ '.toChildren.' oVsys.sName sPath ];
        
        oVsys = oVsys.oParent;
    end
    
    
    sPath = [ oVsys.sName sPath ];
end

