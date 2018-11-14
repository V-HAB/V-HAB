classdef conductive < thermal.procs.conductor
    % creates a conductor for conduction of heat through a material (e.g.
    % metal)
    
    properties (SetAccess = protected)
        
        fResistance; % Thermal resistance of connection in [K/W].
    end
    
    methods
        
        function this = conductive(oContainer, sName, fResistance)
            % Calling the parent constructor
            this@thermal.procs.conductor(oContainer, sName);
            
            % Setting the conductor type to conductive
            this.bConductive = true;
            
            % Set thermal resistance
            this.fResistance = fResistance;
            
        end
        
        function fResistance = update(this, ~)
            % TO DO: implement material dependcy updates here?
            fResistance = this.fResistance;
        end 
    end
    
end

