function sPath = getSysPath(oVsys)
%GETSYSPATH System path WITHOUT the root system!
%   Detailed explanation goes here


    sPath = '';
    
    while ~isa(oVsys.oParent, 'systems.root')
        
        sPath = strcat('.toChildren.', oVsys.sName, sPath);
        
        oVsys = oVsys.oParent;
    end
    
    
    sPath = [ oVsys.sName sPath ];
end

