classdef radiative < thermal.procs.conductor
    %RADIATIVE A radiative conductor transferring heat through thermal radiation
    %   Detailed explanation goes here
    
    properties (SetAccess = protected)
        fResistance; % Thermal resistance of connection in [K^4/W].
    end
    
    methods
        
        function this = radiative(oContainer, sName, fResistance)
            % Calling the parent constructor
            this@thermal.procs.conductor(oContainer, sName);
            
            % Setting the conductor type to radiative
            this.bRadiative  = true;
            
            % Set resistance
            this.fResistance = fResistance;
            
        end
               
        function fResistance = update(this, ~)
            % TO DO: implement material dependcy updates here?
            fResistance = this.fResistance;
        end 
    end
    
end

