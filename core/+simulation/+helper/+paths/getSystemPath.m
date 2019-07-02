function sPath = getSystemPath(oVsys)
%GETSYSTEMPATH System path WITHOUT the root system!
%   Takes the provided system and backtraces through its parents until it
%   arrives at the root system. Concatenates the system names with the
%   string '.toChildren.' to result in a path that is useable for logging
%   purposes, eval() calls and others. 

    % Initializing the return variable
    sPath = '';
    
    % Entering a while loop that checks if oVsys is currently the root
    % system or not. oVsys will be re-assigned in every iteration of this
    % loop. 
    while ~isa(oVsys.oParent, 'systems.root')
        % Adding '.toChildren.' and the name of the current system to the
        % beginning of the current path string
        sPath = strcat('.toChildren.', oVsys.sName, sPath);
        
        % Setting the oVsys variable to the parent of the current system
        oVsys = oVsys.oParent;
    end
    
    % oVsys is the first and only child of the root system, so we can take
    % it's name and add it to th beginning of the path and we're done!
    sPath = [ oVsys.sName sPath ];
end

